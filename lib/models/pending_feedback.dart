import 'package:archive/archive.dart';

/// Data class for a queued feedback submission.
///
/// Stored in Hive box 'feedback_worker_queue' as a Map (no Hive adapter needed).
class PendingFeedback {
  final String id;
  final String type; // 'bug' | 'feature' | 'other'
  final String message;
  final String screenshotB64;
  final String appVersion;
  final String os;
  final String device;
  final DateTime createdAt;

  const PendingFeedback({
    required this.id,
    required this.type,
    required this.message,
    required this.screenshotB64,
    required this.appVersion,
    required this.os,
    required this.device,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'id': id,
      'type': type,
      'message': message,
      'screenshotB64': screenshotB64,
      'appVersion': appVersion,
      'os': os,
      'device': device,
      'createdAt': createdAt.toIso8601String(),
    };
    data['crc'] = getCrc32(canonicalize(data).codeUnits);
    return data;
  }

  factory PendingFeedback.fromMap(Map<String, dynamic> map) {
    return PendingFeedback(
      id: map['id'] as String,
      type: map['type'] as String,
      message: map['message'] as String,
      screenshotB64: map['screenshotB64'] as String,
      appVersion: map['appVersion'] as String,
      os: map['os'] as String,
      device: map['device'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  static String canonicalize(Map<String, dynamic> data) {
    final keys = data.keys.toList()..sort();
    return keys.map((k) => '$k:${data[k]}').join(',');
  }
}
