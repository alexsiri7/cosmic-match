import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/theme/app_theme.dart';

class MapScreen extends StatelessWidget {
  final VoidCallback onBack;

  const MapScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kLyraInk,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'GALAXY MAP — COMING SOON',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: kLyraAccent.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
