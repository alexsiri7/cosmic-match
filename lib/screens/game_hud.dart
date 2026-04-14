import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/cosmic_match_game.dart';
import '../models/level_config.dart';

/// HUD overlay widget showing score, moves remaining, and goal progress.
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
    _game.gameState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _game.gameState.removeListener(_onStateChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final newScore = _game.gameState.score;
    if (newScore != _animatingTo) {
      _animatingFrom = _animatingTo;
      _animatingTo = newScore;
      _animController.forward(from: 0.0);
    }
    setState(() {});
  }

  String _goalLabel() {
    final gs = _game.gameState;
    switch (gs.goalType) {
      case GoalType.clearCount:
        final typeName = gs.targetTileType?.name ?? 'tiles';
        return '$typeName: ${gs.goalProgress}/${gs.goalTarget}';
      case GoalType.reachScore:
        return 'Score: ${gs.score}/${gs.goalTarget}';
      case GoalType.clearAllObstacles:
        return 'Obstacles: ${gs.goalProgress}/${gs.goalTarget}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = _game.gameState;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Moves remaining
                _HudChip(
                  child: Text(
                    'Moves: ${gs.movesRemaining}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                // Score (animated)
                _HudChip(
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      final value =
                          _animatingFrom +
                          ((_animatingTo - _animatingFrom) *
                                  _animController.value)
                              .round();
                      return Text(
                        'Score: $value',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Goal progress
            _HudChip(
              child: Text(
                _goalLabel(),
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final Widget child;

  const _HudChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade300, width: 1),
      ),
      child: child,
    );
  }
}
