import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/match3_game.dart';
import '../game/theme/cosmic_theme.dart';

class HudOverlay extends StatelessWidget {
  final Match3Game game;
  const HudOverlay({required this.game, super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: game.scoreNotifier,
      builder: (context, scores, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              Expanded(flex: 2,
                  child: _StatCard(label: 'SCORE',
                      value: scores.score.toString(),
                      accent: kCosmicAccent)),
              const SizedBox(width: 8),
              Expanded(flex: 1,
                  child: _StatCard(label: 'BEST',
                      value: scores.best.toString(),
                      accent: kCosmicAccent)),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _StatCard({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 9, letterSpacing: 1.5,
                color: Colors.white54)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 20, fontWeight: FontWeight.w500,
                color: accent)),
        ],
      ),
    );
  }
}
