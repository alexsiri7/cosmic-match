import 'package:flutter/material.dart';

import '../game/cosmic_match_game.dart';
import '../main.dart';
import '../utils/star_calculator.dart';

/// Overlay shown when the player wins a level.
class LevelCompleteOverlay extends StatefulWidget {
  final CosmicMatchGame game;

  const LevelCompleteOverlay({super.key, required this.game});

  @override
  State<LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends State<LevelCompleteOverlay> {
  late final int stars;

  @override
  void initState() {
    super.initState();
    final gs = widget.game.gameState;
    stars = StarCalculator.calculateStars(gs.movesRemaining, gs.moveLimit);

    // Save progress to Hive
    final levelId = widget.game.levelConfig?.id;
    if (levelId != null) {
      progressRepository.saveProgress(levelId, stars, gs.score);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = widget.game.gameState;

    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Level Complete!',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // Star rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Icon(
                    i < stars ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 48,
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Score: ${gs.score}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _OverlayButton(
                    label: 'Replay',
                    icon: Icons.replay,
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/game');
                    },
                  ),
                  _OverlayButton(
                    label: 'Next Level',
                    icon: Icons.arrow_forward,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _OverlayButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
