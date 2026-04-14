import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'world/grid_world.dart';

enum GamePhase { idle, swapping, matching, falling, cascading }

// Legal state transitions
const _validTransitions = <GamePhase, Set<GamePhase>>{
  GamePhase.idle:      {GamePhase.swapping},
  GamePhase.swapping:  {GamePhase.matching, GamePhase.idle}, // idle on invalid swap
  GamePhase.matching:  {GamePhase.falling},
  GamePhase.falling:   {GamePhase.cascading, GamePhase.idle},
  GamePhase.cascading: {GamePhase.matching},
};

class Match3Game extends FlameGame<GridWorld> with RiverpodGameMixin {
  Match3Game() : super(world: GridWorld());

  GamePhase _phase = GamePhase.idle;
  GamePhase get phase => _phase;

  void transitionTo(GamePhase next) {
    final allowed = _validTransitions[_phase];
    if (allowed == null || !allowed.contains(next)) {
      // In debug, surface FSM bugs immediately
      assert(false, 'Illegal FSM transition: $_phase → $next');
      // In release, reset to idle rather than entering a corrupt state
      _phase = GamePhase.idle;
      return;
    }
    _phase = next;
  }
}
