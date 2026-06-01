import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cosmic_match/services/progress_service.dart';
import 'package:cosmic_match/models/level_progress.dart';

final _testKey = List<int>.generate(32, (i) => i);

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

  group('ProgressService null-cipher integration', () {
    test('save and load round-trip preserves data', () async {
      final service = ProgressService(hmacKey: _testKey);
      final progress =
          LevelProgress(level: 1, starsEarned: 2, bestScore: 500);
      await service.save(progress);
      final loaded = await service.load(1);
      expect(loaded.level, equals(1));
      expect(loaded.starsEarned, equals(2));
      expect(loaded.bestScore, equals(500));
    });

    test('missing key returns initial progress', () async {
      final service = ProgressService(hmacKey: _testKey);
      final loaded = await service.load(99);
      expect(loaded.level, equals(99));
      expect(loaded.starsEarned, equals(0));
      expect(loaded.bestScore, equals(0));
    });

    test('tampered HMAC returns initial progress', () async {
      final service = ProgressService(hmacKey: _testKey);
      final box = await Hive.openBox('progress');
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

    test('ProgressService() constructs with null cipher by default', () {
      // Verifies the optional cipher parameter is truly optional.
      expect(() => ProgressService(), returnsNormally);
    });
  });
}
