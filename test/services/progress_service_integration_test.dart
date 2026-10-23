import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:cosmic_match/services/progress_service.dart';
import 'package:cosmic_match/models/level_progress.dart';

final _testKey = List<int>.generate(32, (i) => i);
final _testCipher = HiveAesCipher(List<int>.generate(32, (i) => i + 100));

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('ProgressService encrypted integration', () {
    test('save and load round-trip preserves data', () async {
      final service = ProgressService(cipher: _testCipher, hmacKey: _testKey);
      final progress =
          LevelProgress(level: 1, starsEarned: 2, bestScore: 500);
      await service.save(progress);
      final loaded = await service.load(1);
      expect(loaded.level, equals(1));
      expect(loaded.starsEarned, equals(2));
      expect(loaded.bestScore, equals(500));
    });

    test('missing key returns initial progress', () async {
      final service = ProgressService(cipher: _testCipher, hmacKey: _testKey);
      final loaded = await service.load(99);
      expect(loaded.level, equals(99));
      expect(loaded.starsEarned, equals(0));
      expect(loaded.bestScore, equals(0));
    });

    test('tampered HMAC returns initial progress', () async {
      final service = ProgressService(cipher: _testCipher, hmacKey: _testKey);
      final box = await Hive.openBox('progress', encryptionCipher: _testCipher);
      await box.put('level_1', {
        'level': 1,
        'starsEarned': 3,
        'bestScore': 99999,
        'hmac': 'invalid',
      });
      await box.close();
      final loaded = await service.load(1);
      expect(loaded.starsEarned, equals(0));
      expect(loaded.bestScore, equals(0));
    });

    test('validly signed record for another level returns initial', () async {
      final service = ProgressService(cipher: _testCipher, hmacKey: _testKey);
      final box = await Hive.openBox('progress', encryptionCipher: _testCipher);
      await box.put('level_1',
          LevelProgress(level: 2, starsEarned: 3, bestScore: 500).toMap(_testKey));
      await box.close();
      final loaded = await service.load(1);
      expect(loaded.level, equals(1));
      expect(loaded.starsEarned, equals(0));
      expect(loaded.bestScore, equals(0));
    });

    for (final (stars, score) in [(4, 500), (3, -1), (3, 1000000000)]) {
      test('validly signed out-of-range record (stars=$stars, score=$score) '
          'returns initial', () async {
        final service = ProgressService(cipher: _testCipher, hmacKey: _testKey);
        final box = await Hive.openBox('progress', encryptionCipher: _testCipher);
        await box.put('level_1',
            LevelProgress(level: 1, starsEarned: stars, bestScore: score)
                .toMap(_testKey));
        await box.close();
        final loaded = await service.load(1);
        expect(loaded.starsEarned, equals(0));
        expect(loaded.bestScore, equals(0));
      });
    }

    test('ProgressService() constructs without keys', () {
      expect(() => ProgressService(), returnsNormally);
    });
  });

  group('ProgressService null-cipher fail-safe (#317)', () {
    test('save with hmacKey but no cipher skips persist and keeps encrypted data intact',
        () async {
      await ProgressService(cipher: _testCipher, hmacKey: _testKey)
          .save(LevelProgress(level: 1, starsEarned: 2, bestScore: 500));
      await Hive.close();

      // Transient Keystore failure: the cipher is unavailable, the HMAC key is not.
      final degraded = ProgressService(hmacKey: _testKey);
      await degraded.save(LevelProgress(level: 2, starsEarned: 1, bestScore: 100));
      final degradedLoad = await degraded.load(1);
      expect(degradedLoad.bestScore, equals(0));
      await Hive.close();

      final service = ProgressService(cipher: _testCipher, hmacKey: _testKey);
      final loaded = await service.load(1);
      expect(loaded.starsEarned, equals(2),
          reason: 'opening the encrypted box without its cipher must not truncate it');
      expect(loaded.bestScore, equals(500));
      expect((await service.load(2)).bestScore, equals(0),
          reason: 'no record may be written while the cipher is unavailable');
    });
  });

  group('ProgressService null-hmacKey fail-safe', () {
    test('save with null hmacKey skips persist — load returns initial', () async {
      // Simulates secure storage failure: service constructed with hmacKey: null.
      // With the null-key guard, save() is a no-op, so load() returns initial.
      final service = ProgressService(); // hmacKey: null
      final progress = LevelProgress(level: 3, starsEarned: 2, bestScore: 9000);
      await service.save(progress);

      final loaded = await service.load(3);
      expect(loaded.starsEarned, equals(0),
          reason: 'save skipped (null hmacKey) — load must return initial progress');
      expect(loaded.bestScore, equals(0));
    });

    test('save with null hmacKey writes nothing to the box', () async {
      final service = ProgressService(); // hmacKey: null
      await service.save(LevelProgress(level: 5, starsEarned: 3, bestScore: 1000));

      final box = await Hive.openBox('progress');
      expect(box.get('level_5'), isNull,
          reason: 'null-key save must not write any entry to the Hive box');
      await box.close();
    });
  });

  group('ProgressService load with existing data', () {
    test('null hmacKey returns initial even when valid signed data exists',
        () async {
      await ProgressService(cipher: _testCipher, hmacKey: _testKey)
          .save(LevelProgress(level: 1, starsEarned: 2, bestScore: 500));

      final loaded = await ProgressService().load(1);

      expect(loaded.starsEarned, equals(0));
      expect(loaded.bestScore, equals(0));
      expect(loaded.level, equals(1));
    });

    test('data signed with a different key is treated as tampered', () async {
      await ProgressService(cipher: _testCipher, hmacKey: _testKey)
          .save(LevelProgress(level: 1, starsEarned: 2, bestScore: 500));

      final loaded = await ProgressService(
        cipher: _testCipher,
        hmacKey: List<int>.generate(32, (i) => 31 - i),
      ).load(1);

      expect(loaded.starsEarned, equals(0));
      expect(loaded.bestScore, equals(0));
      expect(loaded.level, equals(1));
    });

    test('non-Map stored value returns initial', () async {
      final box = await Hive.openBox('progress', encryptionCipher: _testCipher);
      await box.put('level_1', 'garbage');
      await box.close();

      final loaded = await ProgressService(cipher: _testCipher, hmacKey: _testKey).load(1);

      expect(loaded.starsEarned, equals(0));
      expect(loaded.bestScore, equals(0));
      expect(loaded.level, equals(1));
    });
  });

  group('ProgressService cipher mismatch', () {
    test('load without the cipher returns initial and leaves encrypted data intact',
        () async {
      final cipher = HiveAesCipher(List<int>.generate(32, (i) => i + 100));
      await ProgressService(cipher: cipher, hmacKey: _testKey)
          .save(LevelProgress(level: 1, starsEarned: 2, bestScore: 500));
      await Hive.close();

      final mismatched = await ProgressService(hmacKey: _testKey).load(1);
      expect(mismatched.starsEarned, equals(0));
      expect(mismatched.bestScore, equals(0));
      await Hive.close();

      final restored =
          await ProgressService(cipher: cipher, hmacKey: _testKey).load(1);
      expect(restored.starsEarned, equals(2),
          reason: 'a cipher-mismatched open must not destroy the encrypted box');
      expect(restored.bestScore, equals(500));
    });
  });
}
