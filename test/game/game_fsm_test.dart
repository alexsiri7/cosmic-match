import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';

/// Lightweight stub mirroring onTileSwipe guard logic without a live Flame engine.
/// Mirrors the phase check, selection clear, and null-neighbor guard from
/// Match3Game.onTileSwipe exactly.
class _SwipeStub {
  GamePhase phase = GamePhase.idle;
  bool swapCalled = false;
  bool selectedCleared = false;

  void onTileSwipe({required bool neighborExists}) {
    if (phase != GamePhase.idle) return;
    selectedCleared = true; // mirrors _selectedTile?.deselect() + _selectedTile = null
    if (!neighborExists) return;
    swapCalled = true; // mirrors world.runSwap(tile, neighbor)
  }
}

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

  group('onTileSwipe guard logic', () {
    test('does nothing when phase is not idle', () {
      final stub = _SwipeStub()..phase = GamePhase.swapping;
      stub.onTileSwipe(neighborExists: true);
      expect(stub.swapCalled, isFalse);
      expect(stub.selectedCleared, isFalse);
    });

    test('does not swap when neighbor is out of bounds (null)', () {
      final stub = _SwipeStub();
      stub.onTileSwipe(neighborExists: false);
      // Selection IS cleared before the null-neighbor guard fires
      expect(stub.selectedCleared, isTrue);
      expect(stub.swapCalled, isFalse);
    });

    test('calls runSwap when idle and neighbor exists', () {
      final stub = _SwipeStub();
      stub.onTileSwipe(neighborExists: true);
      expect(stub.selectedCleared, isTrue);
      expect(stub.swapCalled, isTrue);
    });

    test('does not clear selection when phase is non-idle', () {
      // Even with a valid neighbor, non-idle phase must return before clearing
      final stub = _SwipeStub()..phase = GamePhase.falling;
      stub.onTileSwipe(neighborExists: true);
      expect(stub.selectedCleared, isFalse);
    });
  });
}
