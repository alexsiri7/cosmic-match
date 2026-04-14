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
    assert(
      _validTransitions[_phase]!.contains(next),
      'Illegal FSM transition: $_phase → $next',
    );
    _phase = next;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }
}
