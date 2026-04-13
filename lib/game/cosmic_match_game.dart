import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/board_state.dart';
import '../providers/game_state_provider.dart';
import 'components/board_component.dart';

class CosmicMatchGame extends FlameGame {
  late final BoardState boardState;
  late final BoardComponent boardComponent;
  final GameState gameState = GameState();

  @override
  Color backgroundColor() => const Color(0xFF0A0E21);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    boardState = BoardState();
    boardState.randomFill();

    boardComponent = BoardComponent(
      boardState: boardState,
      gameState: gameState,
    );
    add(boardComponent);

    // Show the HUD overlay
    overlays.add('hud');
  }
}
