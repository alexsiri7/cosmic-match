import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/cosmic_match_game.dart';
import '../models/level_config.dart';
import '../utils/level_loader.dart';
import 'game_hud.dart';
import 'level_complete_overlay.dart';
import 'level_failed_overlay.dart';

class GameScreen extends StatefulWidget {
  final int? levelId;

  const GameScreen({super.key, this.levelId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  CosmicMatchGame? _game;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    try {
      LevelConfig? config;
      if (widget.levelId != null) {
        config = await LevelLoader.loadLevel(widget.levelId!);
      }
      setState(() {
        _game = CosmicMatchGame(levelConfig: config);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load level: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    if (_error != null || _game == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error ?? 'Unknown error',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: GameWidget(
        game: _game!,
        overlayBuilderMap: {
          'hud': (context, game) => GameHud(game: game as CosmicMatchGame),
          'levelComplete': (context, game) =>
              LevelCompleteOverlay(game: game as CosmicMatchGame),
          'levelFailed': (context, game) =>
              LevelFailedOverlay(game: game as CosmicMatchGame),
        },
      ),
    );
  }
}
