import 'package:flutter_test/flutter_test.dart';
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
  });
}
