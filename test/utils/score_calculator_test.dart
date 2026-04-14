import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/models/level_config.dart';
import 'package:cosmic_match/models/tile_type.dart';
import 'package:cosmic_match/providers/game_state_provider.dart';
import 'package:cosmic_match/utils/score_calculator.dart';

void main() {
  group('ScoreCalculator', () {
    group('matchPoints', () {
      test('3-match returns 50 points', () {
        expect(ScoreCalculator.matchPoints(3), 50);
      });

      test('4-match returns 150 points', () {
        expect(ScoreCalculator.matchPoints(4), 150);
      });

      test('5-match returns 500 points', () {
        expect(ScoreCalculator.matchPoints(5), 500);
      });

      test('6+ match returns 500 points', () {
        expect(ScoreCalculator.matchPoints(6), 500);
        expect(ScoreCalculator.matchPoints(8), 500);
      });
    });

    group('calculateScore', () {
      test('single 3-match at cascade depth 1', () {
        expect(ScoreCalculator.calculateScore([3], 1), 50);
      });

      test('single 4-match at cascade depth 1', () {
        expect(ScoreCalculator.calculateScore([4], 1), 150);
      });

      test('single 5-match at cascade depth 1', () {
        expect(ScoreCalculator.calculateScore([5], 1), 500);
      });

      test('multiple matches at cascade depth 1', () {
        expect(ScoreCalculator.calculateScore([3, 3], 1), 100);
      });

      test('cascade depth 2 doubles score', () {
        expect(ScoreCalculator.calculateScore([3], 2), 100);
      });

      test('cascade depth 3 triples score', () {
        expect(ScoreCalculator.calculateScore([3], 3), 150);
      });

      test('mixed matches with cascade multiplier', () {
        expect(ScoreCalculator.calculateScore([3, 4], 2), 400);
      });
    });

    group('score clamping', () {
      test('very large cascade depth does not exceed max per call', () {
        // 500 points base * 1000 depth = 500,000 but clamped to 99,999
        final result = ScoreCalculator.calculateScore([5], 1000);
        expect(result, 99999);
      });

      test('moderate cascade depth is not clamped', () {
        // 500 * 20 = 10,000 — under the cap
        final result = ScoreCalculator.calculateScore([5], 20);
        expect(result, 10000);
      });
    });
  });

  group('GameState', () {
    test('initial score is 0', () {
      final state = GameState();
      expect(state.score, 0);
    });

    test('addScore accumulates', () {
      final state = GameState();
      state.addScore(50);
      expect(state.score, 50);
      state.addScore(150);
      expect(state.score, 200);
    });

    test('reset clears score', () {
      final state = GameState();
      state.addScore(500);
      state.reset();
      expect(state.score, 0);
    });

    test('notifies listeners on score change', () {
      final state = GameState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);
      state.addScore(100);
      expect(notifyCount, 1);
      state.addScore(200);
      expect(notifyCount, 2);
    });

    test('initFromLevel sets moves and goal from LevelConfig', () {
      final state = GameState();
      final config = LevelConfig(
        id: 1,
        galaxyIndex: 0,
        goalType: GoalType.clearCount,
        targetTileType: TileType.star,
        targetCount: 20,
        moveLimit: 25,
      );
      state.initFromLevel(config);
      expect(state.movesRemaining, 25);
      expect(state.moveLimit, 25);
      expect(state.goalTarget, 20);
      expect(state.goalType, GoalType.clearCount);
      expect(state.targetTileType, TileType.star);
      expect(state.score, 0);
      expect(state.goalProgress, 0);
    });

    test('useMove decrements movesRemaining', () {
      final state = GameState();
      final config = LevelConfig(
        id: 1,
        galaxyIndex: 0,
        goalType: GoalType.clearCount,
        targetCount: 10,
        moveLimit: 5,
      );
      state.initFromLevel(config);
      state.useMove();
      expect(state.movesRemaining, 4);
      state.useMove();
      expect(state.movesRemaining, 3);
    });

    test('useMove does not go below 0', () {
      final state = GameState();
      final config = LevelConfig(
        id: 1,
        galaxyIndex: 0,
        goalType: GoalType.clearCount,
        targetCount: 10,
        moveLimit: 1,
      );
      state.initFromLevel(config);
      state.useMove();
      expect(state.movesRemaining, 0);
      state.useMove();
      expect(state.movesRemaining, 0);
    });

    test('addGoalProgress accumulates', () {
      final state = GameState();
      final config = LevelConfig(
        id: 1,
        galaxyIndex: 0,
        goalType: GoalType.clearCount,
        targetCount: 20,
        moveLimit: 10,
      );
      state.initFromLevel(config);
      state.addGoalProgress(5);
      expect(state.goalProgress, 5);
      state.addGoalProgress(3);
      expect(state.goalProgress, 8);
    });

    test('goalMet returns true for clearCount when progress >= target', () {
      final state = GameState();
      final config = LevelConfig(
        id: 1,
        galaxyIndex: 0,
        goalType: GoalType.clearCount,
        targetCount: 10,
        moveLimit: 5,
      );
      state.initFromLevel(config);
      expect(state.goalMet, false);
      state.addGoalProgress(10);
      expect(state.goalMet, true);
    });

    test('goalMet returns true for reachScore when score >= target', () {
      final state = GameState();
      final config = LevelConfig(
        id: 1,
        galaxyIndex: 0,
        goalType: GoalType.reachScore,
        targetCount: 500,
        moveLimit: 10,
      );
      state.initFromLevel(config);
      expect(state.goalMet, false);
      state.addScore(500);
      expect(state.goalMet, true);
    });

    test('goalMet returns true for clearAllObstacles when progress >= target', () {
      final state = GameState();
      final config = LevelConfig(
        id: 1,
        galaxyIndex: 0,
        goalType: GoalType.clearAllObstacles,
        targetCount: 5,
        moveLimit: 10,
      );
      state.initFromLevel(config);
      expect(state.goalMet, false);
      state.addGoalProgress(5);
      expect(state.goalMet, true);
    });

    test('goalMet is false when goalTarget is 0 (clearCount goal)', () {
      // reset() leaves _goalTarget = 0 and _goalType = clearCount
      final state = GameState();
      expect(state.goalMet, false);
    });

    test('addGoalProgress is a no-op when goalTarget is 0', () {
      final state = GameState();
      state.addGoalProgress(5);
      expect(state.goalProgress, 0);
      expect(state.goalMet, false);
    });

    test('score accumulation over 20 cascade levels is capped at max score', () {
      final state = GameState();
      // Simulate 20 cascade levels each adding max per-call score (99999 each)
      // Without clamping, total would be 1,999,980 — far over the 999,999 cap
      for (int i = 1; i <= 20; i++) {
        state.addScore(99999);
      }
      expect(state.score, 999999);
    });

    test('score accumulation over 21 cascade levels is still capped', () {
      final state = GameState();
      for (int i = 1; i <= 21; i++) {
        state.addScore(99999);
      }
      expect(state.score, 999999);
    });

    test('isOutOfMoves returns true when moves reach 0', () {
      final state = GameState();
      final config = LevelConfig(
        id: 1,
        galaxyIndex: 0,
        goalType: GoalType.clearCount,
        targetCount: 10,
        moveLimit: 1,
      );
      state.initFromLevel(config);
      expect(state.isOutOfMoves, false);
      state.useMove();
      expect(state.isOutOfMoves, true);
    });

    test('score is capped at 999999', () {
      final state = GameState();
      state.addScore(999998);
      state.addScore(10); // would push to 1,000,008 without clamp
      expect(state.score, 999999);
    });

    test('score does not go negative', () {
      final state = GameState();
      state.addScore(-100); // unusual but defensive
      expect(state.score, 0);
    });

    test('goalProgress cannot exceed goalTarget', () {
      final state = GameState();
      final config = LevelConfig(
        id: 1,
        galaxyIndex: 0,
        goalType: GoalType.clearCount,
        targetCount: 10,
        moveLimit: 20,
      );
      state.initFromLevel(config);
      state.addGoalProgress(5);
      state.addGoalProgress(10); // total would be 15, target is 10
      expect(state.goalProgress, 10);
    });

    test('reset clears all state including moves and goals', () {
      final state = GameState();
      final config = LevelConfig(
        id: 1,
        galaxyIndex: 0,
        goalType: GoalType.clearCount,
        targetTileType: TileType.star,
        targetCount: 20,
        moveLimit: 25,
      );
      state.initFromLevel(config);
      state.addScore(100);
      state.useMove();
      state.addGoalProgress(5);
      state.reset();
      expect(state.score, 0);
      expect(state.movesRemaining, 0);
      expect(state.goalProgress, 0);
      expect(state.goalTarget, 0);
      expect(state.targetTileType, null);
    });
  });
}
