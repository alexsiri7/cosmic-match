import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  GitHubFeedbackClient({http.Client? httpClient})
      : _token = _kToken,
        _client = httpClient ?? http.Client();

  @visibleForTesting
  GitHubFeedbackClient.withToken(String token, {http.Client? httpClient})
      : _token = token,
        _client = httpClient ?? http.Client();

  final String _token;
  final http.Client _client;
  static const _repo = 'alexsiri7/cosmic-match';

  Map<String, String> get _headers => {
        'Authorization': 'token $_token',
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github+json',
      };

  bool get isAvailable => _token.isNotEmpty;

  Future<String> uploadImage(String id, Uint8List pngBytes) async {
    if (_token.isEmpty) {
      throw const FeedbackClientException(
          'Feedback token not configured — cannot upload image');
    }
    gameLogger.d('GitHubFeedbackClient.uploadImage: id=$id');

    final b64 = base64Encode(pngBytes);
    final uri = Uri.parse(
        'https://api.github.com/repos/$_repo/contents/docs/feedback/$id.png');

    final http.Response response;
    try {
      response = await _client
          .put(
            uri,
            headers: _headers,
            body: jsonEncode({
              'message': 'feedback image $id',
              'content': b64,
              'branch': 'main',
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e, stack) {
      gameLogger.w('GitHubFeedbackClient.uploadImage: network error', error: e, stackTrace: stack);
      throw FeedbackClientException('Image upload network error: $e');
    }

    _throwIfError(response, method: 'uploadImage', label: 'Image upload');

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final content = json['content'] as Map<String, dynamic>;
    return content['download_url'] as String;
  }

  Future<String> createIssue(String description, String imageUrl) async {
    if (_token.isEmpty) {
      throw const FeedbackClientException(
          'Feedback token not configured — cannot create issue');
    }
    gameLogger.d('GitHubFeedbackClient.createIssue');

    final uri = Uri.parse('https://api.github.com/repos/$_repo/issues');

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'title': 'In-app feedback',
              'body': '$description\n\n![]($imageUrl)',
              'labels': ['feedback'],
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e, stack) {
      gameLogger.w('GitHubFeedbackClient.createIssue: network error', error: e, stackTrace: stack);
      throw FeedbackClientException('Issue creation network error: $e');
    }

    _throwIfError(response, method: 'createIssue', label: 'Issue creation');

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['html_url'] as String;
  }

  void _throwIfError(
    http.Response response, {
    required String method,
    required String label,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final snippet =
          response.body.substring(0, response.body.length.clamp(0, 200));
      gameLogger.e(
          'GitHubFeedbackClient.$method failed: ${response.statusCode} — $snippet');
      throw FeedbackClientException(
          '$label failed with status ${response.statusCode}');
    }
  }
}
