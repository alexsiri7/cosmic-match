import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/core/crc_integrity.dart';
import 'package:cosmic_match/models/pending_feedback.dart';

final _testKey = List<int>.generate(32, (i) => i);

/// Mirror of FeedbackService._isValid for test-level HMAC validation.
bool _isValid(Map raw) =>
    isValidHmac(raw, canonicalize: PendingFeedback.canonicalize, key: _testKey);

void main() {
  group('PendingFeedback HMAC validation', () {
    test('toMap includes hmac key', () {
      final item = PendingFeedback(
        id: 'hmac-1',
        type: 'bug',
        message: 'test message',
        screenshotB64: 'abc',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel 7',
        createdAt: DateTime(2025, 6, 1),
      );

      final map = item.toMap(_testKey);
      expect(map.containsKey('hmac'), isTrue);
      expect(map['hmac'], isA<String>());
    });

    test('fromMap(toMap()) round-trips all 8 fields', () {
      final original = PendingFeedback(
        id: 'hmac-2',
        type: 'feature',
        message: 'add dark mode please',
        screenshotB64: 'img-data',
        appVersion: '2.0.0+5',
        os: 'ios',
        device: 'iPhone 15',
        createdAt: DateTime(2025, 3, 15, 10, 30),
      );

      final restored = PendingFeedback.fromMap(original.toMap(_testKey));

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.message, original.message);
      expect(restored.screenshotB64, original.screenshotB64);
      expect(restored.appVersion, original.appVersion);
      expect(restored.os, original.os);
      expect(restored.device, original.device);
      expect(restored.createdAt, original.createdAt);
    });

    test('tampered message field detected by HMAC mismatch', () {
      final item = PendingFeedback(
        id: 'hmac-3',
        type: 'bug',
        message: 'original message',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
        createdAt: DateTime(2025, 1, 1),
      );

      final map = item.toMap(_testKey);
      expect(_isValid(map), isTrue);

      map['message'] = 'tampered message';
      expect(_isValid(map), isFalse);
    });

    test('missing hmac key treated as invalid', () {
      final map = <String, dynamic>{
        'id': 'no-hmac',
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
