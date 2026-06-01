import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/core/crc_integrity.dart';
import 'package:cosmic_match/models/level_progress.dart';

final _testKey = List<int>.generate(32, (i) => i);

/// Mirror of ProgressService._isValid for test-level validation.
/// Keeps tests independent of Hive while still exercising the same HMAC logic.
bool _isValid(Map raw) =>
    isValidHmac(raw, canonicalize: LevelProgress.canonicalize, key: _testKey);

void main() {
  group('LevelProgress', () {
    test('initial creates zero-state progress', () {
      final progress = LevelProgress.initial(1);
      expect(progress.level, 1);
      expect(progress.starsEarned, 0);
      expect(progress.bestScore, 0);
    });

    test('toMap includes hmac key', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 3, bestScore: 5000);
      final map = progress.toMap(_testKey);
      expect(map.containsKey('hmac'), isTrue);
      expect(map['hmac'], isA<String>());
    });

    test('fromMap round-trips correctly', () {
      final original =
          LevelProgress(level: 5, starsEarned: 2, bestScore: 12345);
      final map = original.toMap(_testKey);
      final restored = LevelProgress.fromMap(map);
      expect(restored.level, original.level);
      expect(restored.starsEarned, original.starsEarned);
      expect(restored.bestScore, original.bestScore);
    });

    test('HMAC is stable across repeated toMap calls', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 2, bestScore: 100);
      final hmac1 = progress.toMap(_testKey)['hmac'] as String;
      final hmac2 = progress.toMap(_testKey)['hmac'] as String;
      expect(hmac1, equals(hmac2));
    });
  });

  group('ProgressService HMAC validation', () {
    test('valid HMAC passes validation', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 3, bestScore: 5000);
      final map = progress.toMap(_testKey);
      expect(_isValid(map), isTrue);
    });

    test('missing hmac key treated as tampered', () {
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
      final map = progress.toMap(_testKey);
      map['bestScore'] = 999999; // tamper — HMAC unchanged
      expect(_isValid(map), isFalse);
    });

    test('tampered starsEarned is detected', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 1, bestScore: 100);
      final map = progress.toMap(_testKey);
      map['starsEarned'] = 3; // tamper
      expect(_isValid(map), isFalse);
    });

    test('wrong hmac value is detected', () {
      final progress =
          LevelProgress(level: 1, starsEarned: 1, bestScore: 100);
      final map = progress.toMap(_testKey);
      map['hmac'] = 'deadbeef'; // corrupt HMAC
      expect(_isValid(map), isFalse);
    });

    test('HMAC is order-independent (canonicalization)', () {
      // Build maps with same data but different key insertion order
      final progress =
          LevelProgress(level: 2, starsEarned: 2, bestScore: 2000);
      final canonical = progress.toMap(_testKey);

      // Reconstruct with different key order (simulates Hive deserialisation)
      final reordered = <String, dynamic>{
        'hmac': canonical['hmac'],
        'bestScore': canonical['bestScore'],
        'starsEarned': canonical['starsEarned'],
        'level': canonical['level'],
      };
      expect(_isValid(reordered), isTrue);
    });
  });
}
