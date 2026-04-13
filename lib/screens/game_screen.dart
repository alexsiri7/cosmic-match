import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/cosmic_match_game.dart';
import 'game_hud.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = CosmicMatchGame();

    return Scaffold(
      body: GameWidget(
        game: game,
        overlayBuilderMap: {
          'hud': (context, game) => GameHud(game: game as CosmicMatchGame),
        },
      ),
    );
  }
}
