import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/logger.dart';

const String _kToken =
    String.fromEnvironment('GITHUB_FEEDBACK_TOKEN', defaultValue: '');

class FeedbackClientException implements Exception {
  final String message;
  const FeedbackClientException(this.message);
  @override
  String toString() => 'FeedbackClientException: $message';
}

class GitHubFeedbackClient {
  static const _repo = 'alexsiri7/cosmic-match';

  Map<String, String> get _headers => {
        'Authorization': 'token $_kToken',
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github+json',
      };

  bool get isAvailable => _kToken.isNotEmpty;

  Future<String> uploadImage(String id, Uint8List pngBytes) async {
    if (_kToken.isEmpty) {
      throw const FeedbackClientException(
          'Feedback token not configured — cannot upload image');
    }
    gameLogger.d('GitHubFeedbackClient.uploadImage: id=$id');

    final b64 = base64Encode(pngBytes);
    final uri = Uri.parse(
        'https://api.github.com/repos/$_repo/contents/docs/feedback/$id.png');
    final response = await http.put(
      uri,
      headers: _headers,
      body: jsonEncode({
        'message': 'feedback image $id',
        'content': b64,
        'branch': 'main',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      gameLogger.e(
          'GitHubFeedbackClient.uploadImage failed: ${response.statusCode}');
      throw FeedbackClientException(
          'Image upload failed with status ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final content = json['content'] as Map<String, dynamic>;
    return content['download_url'] as String;
  }

  Future<String> createIssue(String description, String imageUrl) async {
    if (_kToken.isEmpty) {
      throw const FeedbackClientException(
          'Feedback token not configured — cannot create issue');
    }
    gameLogger.d('GitHubFeedbackClient.createIssue');

    final uri = Uri.parse('https://api.github.com/repos/$_repo/issues');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'title': 'In-app feedback',
        'body': '$description\n\n![]($imageUrl)',
        'labels': ['feedback'],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      gameLogger.e(
          'GitHubFeedbackClient.createIssue failed: ${response.statusCode}');
      throw FeedbackClientException(
          'Issue creation failed with status ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['html_url'] as String;
  }
}
