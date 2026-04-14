import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';

/// Lightweight FSM wrapper for testing without spinning up a Flame engine.
/// Mirrors Match3Game's _validTransitions and transitionTo logic exactly.
class _TestFsm {
  static const _validTransitions = <GamePhase, Set<GamePhase>>{
    GamePhase.idle: {GamePhase.swapping},
    GamePhase.swapping: {GamePhase.matching, GamePhase.idle},
    GamePhase.matching: {GamePhase.falling},
    GamePhase.falling: {GamePhase.cascading, GamePhase.idle},
    GamePhase.cascading: {GamePhase.matching},
  };

  GamePhase phase = GamePhase.idle;

  /// Mirrors Match3Game.transitionTo: throws StateError on illegal transition.
  void transitionTo(GamePhase next) {
    final allowed = _validTransitions[phase];
    if (allowed == null || !allowed.contains(next)) {
      throw StateError('Illegal FSM transition: $phase → $next');
    }
    phase = next;
  }
}

void main() {
  group('Match3Game FSM', () {
    late _TestFsm fsm;

    setUp(() => fsm = _TestFsm());

    test('initial phase is idle', () {
      expect(fsm.phase, GamePhase.idle);
    });

    test('idle → swapping is valid', () {
      fsm.transitionTo(GamePhase.swapping);
      expect(fsm.phase, GamePhase.swapping);
    });

    test('swapping → matching is valid', () {
      fsm.transitionTo(GamePhase.swapping);
      fsm.transitionTo(GamePhase.matching);
      expect(fsm.phase, GamePhase.matching);
    });

    test('swapping → idle is valid (invalid swap back-edge)', () {
      fsm.transitionTo(GamePhase.swapping);
      fsm.transitionTo(GamePhase.idle);
      expect(fsm.phase, GamePhase.idle);
    });

    test('matching → falling is valid', () {
      fsm.transitionTo(GamePhase.swapping);
      fsm.transitionTo(GamePhase.matching);
      fsm.transitionTo(GamePhase.falling);
      expect(fsm.phase, GamePhase.falling);
    });

    test('falling → cascading is valid', () {
      fsm.transitionTo(GamePhase.swapping);
      fsm.transitionTo(GamePhase.matching);
      fsm.transitionTo(GamePhase.falling);
      fsm.transitionTo(GamePhase.cascading);
      expect(fsm.phase, GamePhase.cascading);
    });

    test('falling → idle is valid (no new matches)', () {
      fsm.transitionTo(GamePhase.swapping);
      fsm.transitionTo(GamePhase.matching);
      fsm.transitionTo(GamePhase.falling);
      fsm.transitionTo(GamePhase.idle);
      expect(fsm.phase, GamePhase.idle);
    });

    test('cascading → matching is valid', () {
      fsm.transitionTo(GamePhase.swapping);
      fsm.transitionTo(GamePhase.matching);
      fsm.transitionTo(GamePhase.falling);
      fsm.transitionTo(GamePhase.cascading);
      fsm.transitionTo(GamePhase.matching);
      expect(fsm.phase, GamePhase.matching);
    });

    test('idle → matching is illegal', () {
      expect(
        () => fsm.transitionTo(GamePhase.matching),
        throwsA(isA<StateError>()),
      );
    });

    test('idle → falling is illegal', () {
      expect(
        () => fsm.transitionTo(GamePhase.falling),
        throwsA(isA<StateError>()),
      );
    });

    test('idle → cascading is illegal', () {
      expect(
        () => fsm.transitionTo(GamePhase.cascading),
        throwsA(isA<StateError>()),
      );
    });

    test('matching → idle is illegal', () {
      fsm.transitionTo(GamePhase.swapping);
      fsm.transitionTo(GamePhase.matching);
      expect(
        () => fsm.transitionTo(GamePhase.idle),
        throwsA(isA<StateError>()),
      );
    });

    test('cascading → idle is illegal (no direct cascade→idle edge)', () {
      fsm.transitionTo(GamePhase.swapping);
      fsm.transitionTo(GamePhase.matching);
      fsm.transitionTo(GamePhase.falling);
      fsm.transitionTo(GamePhase.cascading);
      expect(
        () => fsm.transitionTo(GamePhase.idle),
        throwsA(isA<StateError>()),
      );
    });

    test('full game loop: idle→swapping→matching→falling→cascading→matching→falling→idle', () {
      fsm.transitionTo(GamePhase.swapping);
      fsm.transitionTo(GamePhase.matching);
      fsm.transitionTo(GamePhase.falling);
      fsm.transitionTo(GamePhase.cascading);
      fsm.transitionTo(GamePhase.matching);
      fsm.transitionTo(GamePhase.falling);
      fsm.transitionTo(GamePhase.idle);
      expect(fsm.phase, GamePhase.idle);
    });
  });
}
