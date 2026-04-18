import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/theme/app_theme.dart';

class ModalShell extends StatelessWidget {
  final Widget child;

  const ModalShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: kLyraInk,
              gradient: RadialGradient(
                center: const Alignment(0.0, -1.0),
                radius: 1.2,
                colors: [kLyraNebulaA.withValues(alpha: 0.6), Colors.transparent],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class LevelCompleteModal extends StatelessWidget {
  final int stars;
  final int score;
  final VoidCallback onContinue;
  final VoidCallback onReplay;

  const LevelCompleteModal({
    super.key,
    required this.stars,
    required this.score,
    required this.onContinue,
    required this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    return ModalShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LEVEL 01 · CLEARED',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              letterSpacing: 2.5,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sector\ncomplete',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 16),
          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final filled = i < stars;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.star,
                  size: 54,
                  color: filled ? kLyraAccent : kLyraAccent.withValues(alpha: 0.3),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          // Score card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SCORE',
                        style: GoogleFonts.ibmPlexMono(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: Colors.white.withValues(alpha: 0.6))),
                    Text(score.toString(),
                        style: GoogleFonts.ibmPlexMono(
                            fontSize: 20, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('REWARD',
                        style: GoogleFonts.ibmPlexMono(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: Colors.white.withValues(alpha: 0.6))),
                    Text('+${stars * 100} COSMIC DUST',
                        style: GoogleFonts.ibmPlexMono(
                            fontSize: 13, color: kLyraAccent)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: kLyraAccent,
                foregroundColor: kLyraInk,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
              ),
              child: const Text('Next Level →'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onReplay,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('Replay'),
            ),
          ),
        ],
      ),
    );
  }
}

class LevelFailedModal extends StatelessWidget {
  final int score;
  final VoidCallback onRetry;
  final VoidCallback onQuit;

  const LevelFailedModal({
    super.key,
    required this.score,
    required this.onRetry,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return ModalShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LEVEL 01 · NO MOVES LEFT',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              letterSpacing: 2.5,
              color: kLyraWarning.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Drifting in\nthe void',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Score: $score',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: kLyraAccent,
                foregroundColor: kLyraInk,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: const Text('Retry'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onQuit,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('Galaxy map'),
            ),
          ),
        ],
      ),
    );
  }
}
