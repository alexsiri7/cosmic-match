import 'package:crc32/crc32.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/models/level_progress.dart';

/// Mirror of ProgressService._isValid / _canonicalize for test-level validation.
/// Keeps tests independent of Hive while still exercising the same CRC logic.
bool _isValid(Map raw) {
  final storedCrc = raw['crc'] as int?;
  if (storedCrc == null) return false;
  final data = Map<String, dynamic>.from(raw)..remove('crc');
  return Crc32.compute(_canonicalize(data).codeUnits) == storedCrc;
}

String _canonicalize(Map<String, dynamic> data) {
  final keys = data.keys.toList()..sort();
  return keys.map((k) => '$k:${data[k]}').join(',');
}

void main() {
  group('LevelProgress', () {
    test('initial creates zero-state progress', () {
      final progress = LevelProgress.initial(1);
      expect(progress.level, 1);
      expect(progress.starsEarned, 0);
      expect(progress.bestScore, 0);
    });

    test('toMap includes crc key', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 3, bestScore: 5000);
      final map = progress.toMap();
      expect(map.containsKey('crc'), isTrue);
      expect(map['crc'], isA<int>());
    });

    test('fromMap round-trips correctly', () {
      final original =
          LevelProgress(level: 5, starsEarned: 2, bestScore: 12345);
      final map = original.toMap();
      final restored = LevelProgress.fromMap(map);
      expect(restored.level, original.level);
      expect(restored.starsEarned, original.starsEarned);
      expect(restored.bestScore, original.bestScore);
    });

    test('crc is stable across repeated toMap calls', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 1, bestScore: 100);
      final crc1 = progress.toMap()['crc'] as int;
      final crc2 = progress.toMap()['crc'] as int;
      expect(crc1, equals(crc2));
    });
  });

  group('ProgressService CRC validation', () {
    test('valid CRC passes validation', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 3, bestScore: 5000);
      final map = progress.toMap();
      expect(_isValid(map), isTrue);
    });

    test('missing crc key treated as tampered', () {
      final map = <String, dynamic>{
        'level': 1,
        'starsEarned': 0,
        'bestScore': 0,
      };
      expect(_isValid(map), isFalse);
    });

    test('tampered bestScore is detected', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 1, bestScore: 100);
      final map = progress.toMap();
      map['bestScore'] = 999999; // tamper — CRC unchanged
      expect(_isValid(map), isFalse);
    });

    test('tampered starsEarned is detected', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 1, bestScore: 100);
      final map = progress.toMap();
      map['starsEarned'] = 3; // tamper
      expect(_isValid(map), isFalse);
    });

    test('wrong crc value is detected', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 1, bestScore: 100);
      final map = progress.toMap();
      map['crc'] = 0; // corrupt CRC
      expect(_isValid(map), isFalse);
    });

    test('CRC is order-independent (canonicalization)', () {
      // Build maps with same data but different key insertion order
      final progress =
          LevelProgress(level: 2, starsEarned: 2, bestScore: 2000);
      final canonical = progress.toMap();

      // Reconstruct with different key order (simulates Hive deserialisation)
      final reordered = <String, dynamic>{
        'crc': canonical['crc'],
        'bestScore': canonical['bestScore'],
        'starsEarned': canonical['starsEarned'],
        'level': canonical['level'],
      };
      expect(_isValid(reordered), isTrue);
    });
  });
}
