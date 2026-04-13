import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/cosmic_match_game.dart';

/// HUD overlay widget showing the current score.
/// Built as a Flutter widget (not Flame component) for crisp text rendering.
class GameHud extends StatefulWidget {
  final Game game;

  const GameHud({super.key, required this.game});

  @override
  State<GameHud> createState() => _GameHudState();
}

class _GameHudState extends State<GameHud> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  int _animatingFrom = 0;
  int _animatingTo = 0;

  CosmicMatchGame get _game => widget.game as CosmicMatchGame;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _game.gameState.addListener(_onScoreChanged);
  }

  @override
  void dispose() {
    _game.gameState.removeListener(_onScoreChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onScoreChanged() {
    final newScore = _game.gameState.score;
    if (newScore != _animatingTo) {
      _animatingFrom = _animatingTo;
      _animatingTo = newScore;
      _animController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepPurple.shade300, width: 1),
            ),
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final value = _animatingFrom +
                    ((_animatingTo - _animatingFrom) *
                            _animController.value)
                        .round();
                return Text(
                  'Score: $value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
