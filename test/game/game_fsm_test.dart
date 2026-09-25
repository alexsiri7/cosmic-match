import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';

void main() {
  group('Match3Game FSM', () {
    late Match3Game game;

    setUp(() => game = Match3Game(progressService: null));

    test('initial phase is idle', () {
      expect(game.phase, GamePhase.idle);
    });

    test('idle → swapping is valid', () {
      game.transitionTo(GamePhase.swapping);
      expect(game.phase, GamePhase.swapping);
    });

    test('swapping → matching is valid', () {
      game.transitionTo(GamePhase.swapping);
      game.transitionTo(GamePhase.matching);
      expect(game.phase, GamePhase.matching);
    });

    test('swapping → idle is valid (invalid swap back-edge)', () {
      game.transitionTo(GamePhase.swapping);
      game.transitionTo(GamePhase.idle);
      expect(game.phase, GamePhase.idle);
    });

    test('matching → falling is valid', () {
      game.transitionTo(GamePhase.swapping);
      game.transitionTo(GamePhase.matching);
      game.transitionTo(GamePhase.falling);
      expect(game.phase, GamePhase.falling);
    });

    test('falling → cascading is valid', () {
      game.transitionTo(GamePhase.swapping);
      game.transitionTo(GamePhase.matching);
      game.transitionTo(GamePhase.falling);
      game.transitionTo(GamePhase.cascading);
      expect(game.phase, GamePhase.cascading);
    });

    test('falling → idle is valid (no new matches)', () {
      game.transitionTo(GamePhase.swapping);
      game.transitionTo(GamePhase.matching);
      game.transitionTo(GamePhase.falling);
      game.transitionTo(GamePhase.idle);
      expect(game.phase, GamePhase.idle);
    });

    test('cascading → matching is valid', () {
      game.transitionTo(GamePhase.swapping);
      game.transitionTo(GamePhase.matching);
      game.transitionTo(GamePhase.falling);
      game.transitionTo(GamePhase.cascading);
      game.transitionTo(GamePhase.matching);
      expect(game.phase, GamePhase.matching);
    });

    test('idle → matching is illegal', () {
      expect(
        () => game.transitionTo(GamePhase.matching),
        throwsA(isA<AssertionError>()),
      );
      expect(game.phase, GamePhase.idle);
    });

    test('idle → falling is illegal', () {
      expect(
        () => game.transitionTo(GamePhase.falling),
        throwsA(isA<AssertionError>()),
      );
      expect(game.phase, GamePhase.idle);
    });

    test('idle → cascading is illegal', () {
      expect(
        () => game.transitionTo(GamePhase.cascading),
        throwsA(isA<AssertionError>()),
      );
      expect(game.phase, GamePhase.idle);
    });

    test('matching → idle is illegal', () {
      game.transitionTo(GamePhase.swapping);
      game.transitionTo(GamePhase.matching);
      expect(
        () => game.transitionTo(GamePhase.idle),
        throwsA(isA<AssertionError>()),
      );
      expect(game.phase, GamePhase.idle);
    });

    test('cascading → idle is illegal (no direct cascade→idle edge)', () {
      game.transitionTo(GamePhase.swapping);
      game.transitionTo(GamePhase.matching);
      game.transitionTo(GamePhase.falling);
      game.transitionTo(GamePhase.cascading);
      expect(
        () => game.transitionTo(GamePhase.idle),
        throwsA(isA<AssertionError>()),
      );
      expect(game.phase, GamePhase.idle);
    });

    test('full game loop: idle→swapping→matching→falling→cascading→matching→falling→idle', () {
      game.transitionTo(GamePhase.swapping);
      game.transitionTo(GamePhase.matching);
      game.transitionTo(GamePhase.falling);
      game.transitionTo(GamePhase.cascading);
      game.transitionTo(GamePhase.matching);
      game.transitionTo(GamePhase.falling);
      game.transitionTo(GamePhase.idle);
      expect(game.phase, GamePhase.idle);
    });
  });
}
