import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/models/pending_feedback.dart';

/// Mirror of FeedbackService._isValid for test-level CRC validation.
bool _isValid(Map raw) {
  final storedCrc = raw['crc'] as int?;
  if (storedCrc == null) return false;
  final data = Map<String, dynamic>.from(raw)..remove('crc');
  return getCrc32(PendingFeedback.canonicalize(data).codeUnits) == storedCrc;
}

void main() {
  group('PendingFeedback CRC validation', () {
    test('toMap includes crc key', () {
      final item = PendingFeedback(
        id: 'crc-1',
        type: 'bug',
        message: 'test message',
        screenshotB64: 'abc',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel 7',
        createdAt: DateTime(2025, 6, 1),
      );

      final map = item.toMap();
      expect(map.containsKey('crc'), isTrue);
      expect(map['crc'], isA<int>());
    });

    test('fromMap(toMap()) round-trips all 8 fields', () {
      final original = PendingFeedback(
        id: 'crc-2',
        type: 'feature',
        message: 'add dark mode please',
        screenshotB64: 'img-data',
        appVersion: '2.0.0+5',
        os: 'ios',
        device: 'iPhone 15',
        createdAt: DateTime(2025, 3, 15, 10, 30),
      );

      final restored = PendingFeedback.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.message, original.message);
      expect(restored.screenshotB64, original.screenshotB64);
      expect(restored.appVersion, original.appVersion);
      expect(restored.os, original.os);
      expect(restored.device, original.device);
      expect(restored.createdAt, original.createdAt);
    });

    test('tampered message field detected by CRC mismatch', () {
      final item = PendingFeedback(
        id: 'crc-3',
        type: 'bug',
        message: 'original message',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
        createdAt: DateTime(2025, 1, 1),
      );

      final map = item.toMap();
      expect(_isValid(map), isTrue);

      map['message'] = 'tampered message';
      expect(_isValid(map), isFalse);
    });

    test('missing crc key treated as invalid', () {
      final map = <String, dynamic>{
        'id': 'no-crc',
        'type': 'bug',
        'message': 'test',
        'screenshotB64': '',
        'appVersion': '1.0.0+1',
        'os': 'android',
        'device': 'test',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      };

      expect(_isValid(map), isFalse);
    });
  });
}
