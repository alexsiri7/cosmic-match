import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/board_state.dart';
import '../models/level_config.dart';
import '../providers/game_state_provider.dart';
import 'components/board_component.dart';

class CosmicMatchGame extends FlameGame {
  late final BoardState boardState;
  late final BoardComponent boardComponent;
  final GameState gameState = GameState();
  final LevelConfig? levelConfig;

  CosmicMatchGame({this.levelConfig});

  @override
  Color backgroundColor() => const Color(0xFF0A0E21);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    boardState = BoardState();
    boardState.randomFill();

    // Initialize game state from level config (or use defaults)
    if (levelConfig != null) {
      gameState.initFromLevel(levelConfig!);
    }

    boardComponent = BoardComponent(
      boardState: boardState,
      gameState: gameState,
      levelConfig: levelConfig,
    );
    add(boardComponent);

    // Show the HUD overlay
    overlays.add('hud');
  }
}
