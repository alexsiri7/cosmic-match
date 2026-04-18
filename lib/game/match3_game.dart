import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'components/grid_tile.dart';
import 'world/grid_world.dart';
import '../core/logger.dart';
import '../services/progress_service.dart';

enum GamePhase { idle, swapping, matching, falling, cascading }

// Legal state transitions
const _validTransitions = <GamePhase, Set<GamePhase>>{
  GamePhase.idle: {GamePhase.swapping},
  GamePhase.swapping: {GamePhase.matching, GamePhase.idle}, // idle on invalid swap
  GamePhase.matching: {GamePhase.falling},
  GamePhase.falling: {GamePhase.cascading, GamePhase.idle},
  GamePhase.cascading: {GamePhase.matching},
};

class Match3Game extends FlameGame<GridWorld> with RiverpodGameMixin {
  final ProgressService? progressService;
  final scoreNotifier = ValueNotifier<({int score, int best})>((score: 0, best: 0));

  Match3Game({this.progressService, Random? rng})
      : super(world: GridWorld(rng: rng));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Align world (0,0) with the top-left of the viewport so GridWorld's
    // layout math (which computes positions relative to top-left) renders
    // the board correctly instead of drifting into the bottom-right.
    camera.viewfinder.anchor = Anchor.topLeft;
    if (overlays.registeredOverlays.contains('hud')) {
      overlays.add('hud');
    }
    gameLogger.d('Match3Game loaded');
  }

  GamePhase _phase = GamePhase.idle;
  GamePhase get phase => _phase;

  GridTile? _selectedTile;

  void transitionTo(GamePhase next) {
    final allowed = _validTransitions[_phase];
    if (allowed == null || !allowed.contains(next)) {
      // Debug: crash immediately; release: reset to idle rather than corrupt state.
      assert(false, 'Illegal FSM transition: $_phase → $next');
      _phase = GamePhase.idle;
      return;
    }
    _phase = next;
  }

  void onTileTap(GridTile tile) {
    if (_selectedTile == null) {
      _selectedTile = tile;
      tile.select();
      return;
    }

    if (tile == _selectedTile) {
      tile.deselect();
      _selectedTile = null;
      return;
    }

    // Check adjacency
    final dx = (tile.gridX - _selectedTile!.gridX).abs();
    final dy = (tile.gridY - _selectedTile!.gridY).abs();
    if (dx + dy != 1) {
      // Not adjacent — switch selection
      _selectedTile!.deselect();
      _selectedTile = tile;
      tile.select();
      return;
    }

    // Adjacent — initiate swap
    final tileA = _selectedTile!;
    tileA.deselect();
    _selectedTile = null;
    world.runSwap(tileA, tile);
  }
}
