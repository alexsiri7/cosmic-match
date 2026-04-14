import 'package:flutter/foundation.dart';

import '../models/level_config.dart';
import '../models/tile_type.dart';

/// Manages game state (score, moves, goal progress) as a ChangeNotifier.
/// Shared between Flame game components and Flutter overlay widgets.
class GameState extends ChangeNotifier {
  int _score = 0;
  int _displayedScore = 0;
  int _movesRemaining = 0;
  int _moveLimit = 0;
  int _goalProgress = 0;
  int _goalTarget = 0;
  GoalType _goalType = GoalType.clearCount;
  TileType? _targetTileType;

  static const int _maxScore = 999999;

  int get score => _score;
  int get displayedScore => _displayedScore;
  int get movesRemaining => _movesRemaining;
  int get moveLimit => _moveLimit;
  int get goalProgress => _goalProgress;
  int get goalTarget => _goalTarget;
  GoalType get goalType => _goalType;
  TileType? get targetTileType => _targetTileType;

  /// Whether the goal has been met.
  bool get goalMet {
    switch (_goalType) {
      case GoalType.clearCount:
      case GoalType.clearAllObstacles:
        return _goalProgress >= _goalTarget;
      case GoalType.reachScore:
        return _score >= _goalTarget;
    }
  }

  /// Whether the player has lost (no moves remaining and goal not met).
  bool get isOutOfMoves => _movesRemaining <= 0;

  /// Initialize state from a level config.
  void initFromLevel(LevelConfig config) {
    _score = 0;
    _displayedScore = 0;
    _movesRemaining = config.moveLimit;
    _moveLimit = config.moveLimit;
    _goalProgress = 0;
    _goalTarget = config.targetCount;
    _goalType = config.goalType;
    _targetTileType = config.targetTileType;
    notifyListeners();
  }

  void addScore(int points) {
    _score = (_score + points).clamp(0, _maxScore);
    notifyListeners();
  }

  /// Called by the HUD animation to update the displayed (animated) score.
  void updateDisplayedScore(int value) {
    _displayedScore = value;
    notifyListeners();
  }

  /// Decrement moves by 1 after a valid swap.
  void useMove() {
    if (_movesRemaining > 0) {
      _movesRemaining--;
      notifyListeners();
    }
  }

  /// Add to goal progress (e.g. tiles cleared of target type, obstacles cleared).
  void addGoalProgress(int amount) {
    _goalProgress = (_goalProgress + amount).clamp(0, _goalTarget);
    notifyListeners();
  }

  void reset() {
    _score = 0;
    _displayedScore = 0;
    _movesRemaining = 0;
    _moveLimit = 0;
    _goalProgress = 0;
    _goalTarget = 0;
    _goalType = GoalType.clearCount;
    _targetTileType = null;
    notifyListeners();
  }
}
