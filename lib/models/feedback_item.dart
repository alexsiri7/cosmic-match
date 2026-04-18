import 'package:archive/archive.dart';

class FeedbackItem {
  final String id;
  final DateTime timestamp;
  final String description;
  final String screenshotBase64;
  final bool uploaded;
  final String? githubIssueUrl;

  const FeedbackItem({
    required this.id,
    required this.timestamp,
    required this.description,
    required this.screenshotBase64,
    this.uploaded = false,
    this.githubIssueUrl,
  });

  FeedbackItem copyWith({
    bool? uploaded,
    String? githubIssueUrl,
  }) {
    return FeedbackItem(
      id: id,
      timestamp: timestamp,
      description: description,
      screenshotBase64: screenshotBase64,
      uploaded: uploaded ?? this.uploaded,
      githubIssueUrl: githubIssueUrl ?? this.githubIssueUrl,
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'description': description,
      'screenshotBase64': screenshotBase64,
      'uploaded': uploaded,
      'githubIssueUrl': githubIssueUrl,
    };
    data['crc'] = getCrc32(canonicalize(data).codeUnits);
    return data;
  }

  factory FeedbackItem.fromMap(Map raw) {
    return FeedbackItem(
      id: raw['id'] as String,
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(raw['timestamp'] as int),
      description: raw['description'] as String,
      screenshotBase64: raw['screenshotBase64'] as String,
      uploaded: raw['uploaded'] as bool? ?? false,
      githubIssueUrl: raw['githubIssueUrl'] as String?,
    );
  }

  static String canonicalize(Map<String, dynamic> data) {
    final keys = data.keys.toList()..sort();
    return keys.map((k) => '$k:${data[k]}').join(',');
  }
}
