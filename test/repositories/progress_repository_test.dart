import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:cosmic_match/models/level_progress.dart';
import 'package:cosmic_match/repositories/progress_repository.dart';

void main() {
  late Directory tempDir;
  late Box<LevelProgress> progressBox;
  late Box<dynamic> settingsBox;
  late ProgressRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LevelProgressAdapter());
    }
    progressBox = await Hive.openBox<LevelProgress>('test_progress');
    settingsBox = await Hive.openBox<dynamic>('test_settings');
    repo = ProgressRepository(
      progressBox: progressBox,
      settingsBox: settingsBox,
    );
  });

  tearDown(() async {
    await progressBox.clear();
    await settingsBox.clear();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('ProgressRepository', () {
    test('saveProgress creates new entry', () {
      repo.saveProgress(1, 3, 1500);
      final progress = repo.getProgress(1);
      expect(progress, isNotNull);
      expect(progress!.levelId, 1);
      expect(progress.stars, 3);
      expect(progress.highScore, 1500);
      expect(progress.completed, true);
    });

    test('saveProgress updates existing entry with better stars', () {
      repo.saveProgress(1, 1, 500);
      repo.saveProgress(1, 3, 400);
      final progress = repo.getProgress(1);
      expect(progress!.stars, 3);
      // High score should remain 500 (better)
      expect(progress.highScore, 500);
    });

    test('saveProgress does not downgrade stars', () {
      repo.saveProgress(1, 3, 1500);
      repo.saveProgress(1, 1, 200);
      final progress = repo.getProgress(1);
      expect(progress!.stars, 3);
    });

    test('saveProgress updates high score if higher', () {
      repo.saveProgress(1, 2, 1000);
      repo.saveProgress(1, 1, 2000);
      final progress = repo.getProgress(1);
      expect(progress!.highScore, 2000);
    });

    test('getProgress returns null for unplayed level', () {
      expect(repo.getProgress(99), isNull);
    });

    test('getAllProgress returns all saved entries', () {
      repo.saveProgress(1, 3, 1500);
      repo.saveProgress(2, 2, 1000);
      repo.saveProgress(5, 1, 300);
      final all = repo.getAllProgress();
      expect(all.length, 3);
      expect(all.keys, containsAll([1, 2, 5]));
    });

    test('getHighestUnlockedLevel returns 1 with no progress', () {
      expect(repo.getHighestUnlockedLevel(), 1);
    });

    test('getHighestUnlockedLevel returns next level after completed', () {
      repo.saveProgress(1, 2, 800);
      expect(repo.getHighestUnlockedLevel(), 2);
    });

    test('getHighestUnlockedLevel handles non-sequential completion', () {
      repo.saveProgress(1, 3, 1500);
      repo.saveProgress(2, 2, 1000);
      repo.saveProgress(3, 1, 500);
      expect(repo.getHighestUnlockedLevel(), 4);
    });

    test('soundEnabled defaults to true', () {
      expect(repo.soundEnabled, true);
    });

    test('musicEnabled defaults to true', () {
      expect(repo.musicEnabled, true);
    });

    test('soundEnabled persists changes', () {
      repo.soundEnabled = false;
      expect(repo.soundEnabled, false);
      repo.soundEnabled = true;
      expect(repo.soundEnabled, true);
    });

    test('musicEnabled persists changes', () {
      repo.musicEnabled = false;
      expect(repo.musicEnabled, false);
    });
  });
}
