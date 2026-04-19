import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';

/// Integration tests for FSM transitions on the real Match3Game object
/// (not the lightweight _TestFsm wrapper in game_fsm_test.dart).
/// These verify that transitionTo and phase work correctly on the actual
/// game class, including the assert-and-reset behavior for illegal transitions.
void main() {
  group('Match3Game cascade FSM integration', () {
    test('initial phase is idle', () {
      final game = Match3Game(progressService: null);
      expect(game.phase, GamePhase.idle);
    });

    test('valid FSM transitions work on real game object', () {
      final game = Match3Game(progressService: null);

      // idle → swapping
      game.transitionTo(GamePhase.swapping);
      expect(game.phase, GamePhase.swapping);

      // swapping → matching
      game.transitionTo(GamePhase.matching);
      expect(game.phase, GamePhase.matching);

      // matching → falling
      game.transitionTo(GamePhase.falling);
      expect(game.phase, GamePhase.falling);

      // falling → cascading
      game.transitionTo(GamePhase.cascading);
      expect(game.phase, GamePhase.cascading);

      // cascading → matching (cascade loop)
      game.transitionTo(GamePhase.matching);
      expect(game.phase, GamePhase.matching);
    });

    test('scoreNotifier initial value is (score: 0, best: 0)', () {
      final game = Match3Game(progressService: null);
      expect(game.scoreNotifier.value.score, equals(0));
      expect(game.scoreNotifier.value.best, equals(0));
    });

    test('illegal transition idle → cascading asserts in debug mode', () {
      final game = Match3Game(progressService: null);
      expect(game.phase, GamePhase.idle);

      // flutter test always runs with asserts enabled (debug mode), so
      // transitionTo() fires the AssertionError before resetting to idle.
      // In release builds, the assert is absent and the phase silently resets
      // to idle instead (see CLAUDE.md FSM Transitions invariant).
      expect(
        () => game.transitionTo(GamePhase.cascading),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
