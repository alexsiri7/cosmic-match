import '../core/crc_integrity.dart';

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

  /// Retryable worker responses this item has received (#327).
  final int attempts;

  /// When the item may next be posted; null means it is due now.
  final DateTime? nextRetryAt;

  const PendingFeedback({
    required this.id,
    required this.type,
    required this.message,
    required this.screenshotB64,
    required this.appVersion,
    required this.os,
    required this.device,
    required this.createdAt,
    this.attempts = 0,
    this.nextRetryAt,
  });

  PendingFeedback afterFailedAttempt(DateTime nextRetryAt) => PendingFeedback(
        id: id,
        type: type,
        message: message,
        screenshotB64: screenshotB64,
        appVersion: appVersion,
        os: os,
        device: device,
        createdAt: createdAt,
        attempts: attempts + 1,
        nextRetryAt: nextRetryAt,
      );

  Map<String, dynamic> toMap(List<int>? hmacKey) {
    final data = <String, dynamic>{
      'id': id,
      'type': type,
      'message': message,
      'screenshotB64': screenshotB64,
      'appVersion': appVersion,
      'os': os,
      'device': device,
      'createdAt': createdAt.toIso8601String(),
      'attempts': attempts,
      if (nextRetryAt != null) 'nextRetryAt': nextRetryAt!.toIso8601String(),
    };
    if (hmacKey != null) {
      data['hmac'] = computeHmac(canonicalizeMap(data), hmacKey);
    }
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
      attempts: map['attempts'] as int? ?? 0,
      nextRetryAt: switch (map['nextRetryAt']) {
        final String s => DateTime.parse(s),
        _ => null,
      },
    );
  }
}
