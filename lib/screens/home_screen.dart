import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onMap;
  final VoidCallback onFeedback;

  const HomeScreen({super.key, required this.onPlay, required this.onMap, required this.onFeedback});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kLyraInk,
        gradient: RadialGradient(
          center: const Alignment(0.0, -0.6),
          radius: 1.2,
          colors: [kLyraNebulaA.withValues(alpha: 0.6), Colors.transparent],
        ),
      ),
      child: Stack(
        children: [
          // Secondary nebula gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.6, 0.6),
                radius: 1.2,
                colors: [kLyraNebulaB.withValues(alpha: 0.5), Colors.transparent],
              ),
            ),
          ),
          // Static starfield
          ..._buildStarfield(80, 1, MediaQuery.sizeOf(context)),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
                  Text(
                    'GALAXY · LYRA',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: kLyraAccent.withValues(alpha: 0.85),
                    ),
                  ),
                  // Hero section
                  const Spacer(),
                  Text(
                    'A MATCH-3 ODYSSEY',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 13,
                      letterSpacing: 3,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cosmic\nMatch',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -2.5,
                      height: 0.92,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kLyraAccent,
                          boxShadow: [BoxShadow(color: kLyraAccent, blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '50 levels · 5 galaxies · portrait only',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Resume card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESUME',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Level 1',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                                SizedBox(height: 2),
                                Text('Lyra Sector',
                                    style: TextStyle(fontSize: 12, color: Colors.white54)),
                              ],
                            ),
                            Row(
                              children: List.generate(3, (i) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Icon(
                                    Icons.star,
                                    size: 14,
                                    color: i == 0
                                        ? kLyraAccent
                                        : kLyraAccent.withValues(alpha: 0.3),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Play button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onPlay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kLyraAccent,
                        foregroundColor: kLyraInk,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
                      child: const Text('▶  PLAY LEVEL 1'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Map button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onMap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                        textStyle: const TextStyle(fontSize: 14, letterSpacing: 0.3),
                      ),
                      child: const Text('Galaxy Map'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onFeedback,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.45),
                      textStyle: const TextStyle(fontSize: 12, letterSpacing: 0.3),
                    ),
                    child: const Text('Send feedback'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStarfield(int density, int seed, Size screenSize) {
    // Deterministic LCG (Lehmer / Numerical Recipes params) so the starfield
    // is identical on every rebuild without needing State. Positions are scaled
    // to actual screen dimensions so stars fill the full viewport.
    final stars = <Widget>[];
    int s = seed * 9301 + 49297;
    double rnd() {
      s = (s * 9301 + 49297) % 233280;
      return s / 233280;
    }

    for (int i = 0; i < density; i++) {
      final x = rnd();
      final y = rnd();
      final size = rnd() * 1.6 + 0.4;
      final opacity = rnd() * 0.6 + 0.3;
      stars.add(
        Positioned(
          left: x * screenSize.width,
          top: y * screenSize.height,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: opacity),
            ),
          ),
        ),
      );
    }
    return stars;
  }
}
