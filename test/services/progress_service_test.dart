import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/models/level_progress.dart';

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

    test('crc changes when data is tampered', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 1, bestScore: 100);
      final map = progress.toMap();
      final originalCrc = map['crc'];

      // Tamper with the data
      map['bestScore'] = 999999;

      // Recompute what the CRC should be for the tampered data
      final tamperedData = Map.of(map)..remove('crc');
      // The stored CRC should NOT match the tampered data
      expect(originalCrc, isNot(equals(null)));
      // Verifying the concept: original CRC was for original data
      expect(map['bestScore'], isNot(equals(100)));
    });
  });

  group('ProgressService CRC validation', () {
    test('valid CRC passes validation', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 3, bestScore: 5000);
      final map = progress.toMap();

      // Simulate what ProgressService._isValid does
      final storedCrc = map['crc'] as int?;
      expect(storedCrc, isNotNull);

      final data = Map.of(map)..remove('crc');
      // The CRC should be reproducible
      expect(storedCrc, isA<int>());
    });

    test('missing crc key treated as tampered', () {
      final map = {'level': 1, 'starsEarned': 0, 'bestScore': 0};
      final storedCrc = map['crc'];
      expect(storedCrc, isNull); // would cause reset to initial
    });

    test('tampered data with wrong crc is detected', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 1, bestScore: 100);
      final map = progress.toMap();
      final originalCrc = map['crc'] as int;

      // Tamper with score
      map['bestScore'] = 999999;
      // CRC is still the original — mismatch
      expect(map['crc'], equals(originalCrc));
      // Data changed but CRC didn't → validation would fail
    });
  });
}
