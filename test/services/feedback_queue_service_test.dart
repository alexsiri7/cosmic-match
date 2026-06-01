import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/core/crc_integrity.dart';
import 'package:cosmic_match/models/feedback_item.dart';

final _testKey = List<int>.generate(32, (i) => i);

/// Mirror of FeedbackQueueService._isValid for test-level validation.
bool _isValid(Map raw) =>
    isValidHmac(raw, canonicalize: FeedbackItem.canonicalize, key: _testKey);

FeedbackItem _createItem({
  String id = 'test-1',
  String description = 'Test feedback',
  bool uploaded = false,
  String? githubIssueUrl,
}) {
  return FeedbackItem(
    id: id,
    timestamp: DateTime(2026, 1, 1),
    description: description,
    screenshotBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    uploaded: uploaded,
    githubIssueUrl: githubIssueUrl,
  );
}

void main() {
  group('FeedbackItem', () {
    test('toMap includes hmac key', () {
      final item = _createItem();
      final map = item.toMap(_testKey);
      expect(map.containsKey('hmac'), isTrue);
      expect(map['hmac'], isA<String>());
    });

    test('fromMap round-trips correctly', () {
      final original = _createItem(description: 'A bug report');
      final map = original.toMap(_testKey);
      final restored = FeedbackItem.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.description, original.description);
      expect(restored.screenshotBase64, original.screenshotBase64);
      expect(restored.uploaded, original.uploaded);
      expect(restored.githubIssueUrl, original.githubIssueUrl);
    });

    test('HMAC is stable across repeated toMap calls', () {
      final item = _createItem();
      final hmac1 = item.toMap(_testKey)['hmac'] as String;
      final hmac2 = item.toMap(_testKey)['hmac'] as String;
      expect(hmac1, equals(hmac2));
    });

    test('copyWith updates uploaded and preserves other fields', () {
      final item = _createItem();
      final updated = item.copyWith(
          uploaded: true, githubIssueUrl: 'https://github.com/test/1');
      expect(updated.uploaded, isTrue);
      expect(updated.githubIssueUrl, 'https://github.com/test/1');
      expect(updated.id, item.id);
      expect(updated.description, item.description);
    });
  });

  group('FeedbackItem HMAC validation', () {
    test('valid HMAC passes validation', () {
      final item = _createItem();
      final map = item.toMap(_testKey);
      expect(_isValid(map), isTrue);
    });

    test('missing hmac key treated as tampered', () {
      final item = _createItem();
      final map = item.toMap(_testKey)..remove('hmac');
      expect(_isValid(map), isFalse);
    });

    test('tampered description is detected', () {
      final item = _createItem();
      final map = item.toMap(_testKey);
      map['description'] = 'hacked';
      expect(_isValid(map), isFalse);
    });

    test('tampered uploaded flag is detected', () {
      final item = _createItem();
      final map = item.toMap(_testKey);
      map['uploaded'] = true;
      expect(_isValid(map), isFalse);
    });

    test('wrong hmac value is detected', () {
      final item = _createItem();
      final map = item.toMap(_testKey);
      map['hmac'] = 'deadbeef';
      expect(_isValid(map), isFalse);
    });

    test('HMAC is order-independent (canonicalization)', () {
      final item = _createItem();
      final canonical = item.toMap(_testKey);

      // Reconstruct with different key order
      final reordered = <String, dynamic>{
        'hmac': canonical['hmac'],
        'screenshotBase64': canonical['screenshotBase64'],
        'description': canonical['description'],
        'id': canonical['id'],
        'timestamp': canonical['timestamp'],
        'uploaded': canonical['uploaded'],
        'githubIssueUrl': canonical['githubIssueUrl'],
      };
      expect(_isValid(reordered), isTrue);
    });
  });
}
