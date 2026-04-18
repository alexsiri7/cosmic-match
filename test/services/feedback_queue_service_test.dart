import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/models/feedback_item.dart';

/// Mirror of FeedbackQueueService._isValid for test-level validation.
bool _isValid(Map raw) {
  final storedCrc = raw['crc'] as int?;
  if (storedCrc == null) return false;
  final data = Map<String, dynamic>.from(raw)..remove('crc');
  return getCrc32(FeedbackItem.canonicalize(data).codeUnits) == storedCrc;
}

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
    test('toMap includes crc key', () {
      final item = _createItem();
      final map = item.toMap();
      expect(map.containsKey('crc'), isTrue);
      expect(map['crc'], isA<int>());
    });

    test('fromMap round-trips correctly', () {
      final original = _createItem(description: 'A bug report');
      final map = original.toMap();
      final restored = FeedbackItem.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.description, original.description);
      expect(restored.screenshotBase64, original.screenshotBase64);
      expect(restored.uploaded, original.uploaded);
      expect(restored.githubIssueUrl, original.githubIssueUrl);
    });

    test('crc is stable across repeated toMap calls', () {
      final item = _createItem();
      final crc1 = item.toMap()['crc'] as int;
      final crc2 = item.toMap()['crc'] as int;
      expect(crc1, equals(crc2));
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

  group('FeedbackItem CRC validation', () {
    test('valid CRC passes validation', () {
      final item = _createItem();
      final map = item.toMap();
      expect(_isValid(map), isTrue);
    });

    test('missing crc key treated as tampered', () {
      final item = _createItem();
      final map = item.toMap()..remove('crc');
      expect(_isValid(map), isFalse);
    });

    test('tampered description is detected', () {
      final item = _createItem();
      final map = item.toMap();
      map['description'] = 'hacked';
      expect(_isValid(map), isFalse);
    });

    test('tampered uploaded flag is detected', () {
      final item = _createItem();
      final map = item.toMap();
      map['uploaded'] = true;
      expect(_isValid(map), isFalse);
    });

    test('wrong crc value is detected', () {
      final item = _createItem();
      final map = item.toMap();
      map['crc'] = 0;
      expect(_isValid(map), isFalse);
    });

    test('CRC is order-independent (canonicalization)', () {
      final item = _createItem();
      final canonical = item.toMap();

      // Reconstruct with different key order
      final reordered = <String, dynamic>{
        'crc': canonical['crc'],
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
