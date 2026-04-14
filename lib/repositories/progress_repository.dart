import 'package:hive/hive.dart';

import '../models/level_progress.dart';

/// Repository for reading and writing level progress and settings via Hive.
class ProgressRepository {
  static const String progressBoxName = 'progress';
  static const String settingsBoxName = 'settings';

  final Box<LevelProgress> _progressBox;
  final Box<dynamic> _settingsBox;

  ProgressRepository({
    required Box<LevelProgress> progressBox,
    required Box<dynamic> settingsBox,
  }) : _progressBox = progressBox,
       _settingsBox = settingsBox;

  /// Save or update progress for a level.
  /// Only updates stars and highScore if the new values are better.
  void saveProgress(int levelId, int stars, int score) {
    final existing = _progressBox.get(levelId);
    if (existing != null) {
      existing.completed = true;
      if (stars > existing.stars) {
        existing.stars = stars;
      }
      if (score > existing.highScore) {
        existing.highScore = score;
      }
      _progressBox.put(levelId, existing);
    } else {
      _progressBox.put(
        levelId,
        LevelProgress(
          levelId: levelId,
          stars: stars,
          highScore: score,
          completed: true,
        ),
      );
    }
  }

  /// Get progress for a specific level, or null if not played.
  LevelProgress? getProgress(int levelId) {
    return _progressBox.get(levelId);
  }

  /// Get all saved progress entries.
  Map<int, LevelProgress> getAllProgress() {
    final map = <int, LevelProgress>{};
    for (final key in _progressBox.keys) {
      final progress = _progressBox.get(key);
      if (progress != null) {
        map[key as int] = progress;
      }
    }
    return map;
  }

  /// Returns the highest level number that the player has unlocked.
  /// Level 1 is always unlocked. Completing level N unlocks level N+1.
  int getHighestUnlockedLevel() {
    int highest = 1; // Level 1 always unlocked
    for (final key in _progressBox.keys) {
      final progress = _progressBox.get(key);
      if (progress != null && progress.completed) {
        final nextLevel = (key as int) + 1;
        if (nextLevel > highest) {
          highest = nextLevel;
        }
      }
    }
    return highest;
  }

  // --- Settings ---

  bool get soundEnabled =>
      _settingsBox.get('soundEnabled', defaultValue: true) as bool;
  set soundEnabled(bool value) => _settingsBox.put('soundEnabled', value);

  bool get musicEnabled =>
      _settingsBox.get('musicEnabled', defaultValue: true) as bool;
  set musicEnabled(bool value) => _settingsBox.put('musicEnabled', value);
}
