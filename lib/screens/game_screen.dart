import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/match3_game.dart';
import '../game/theme/app_theme.dart';

/// Formats a game score for display.
/// Exposed for unit testing via [@visibleForTesting].
@visibleForTesting
String formatGameScore(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  // Use integer division (~/) to avoid floating-point rounding (e.g. 1500/1000=1.5→2).
  if (n >= 1000) return '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}';
  return n.toString();
}

class GameScreen extends StatefulWidget {
  final Match3Game game;
  final VoidCallback onBack;
  final VoidCallback onFeedback;

  const GameScreen({super.key, required this.game, required this.onBack, required this.onFeedback});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _gameKey = GlobalKey<RiverpodAwareGameWidgetState<Match3Game>>();
  final _repaintKey = GlobalKey();

  Future<Uint8List> captureScreenshot() async {
    final boundary = _repaintKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kLyraInk,
      child: SafeArea(
        child: Column(
          children: [
            _buildHUD(),
            Expanded(
              child: RepaintBoundary(
                key: _repaintKey,
                child: RiverpodAwareGameWidget(
                  key: _gameKey,
                  game: widget.game,
                ),
              ),
            ),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: [
          // Top row: back, level label, pause
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleButton(
                onTap: widget.onBack,
                child: const Icon(Icons.chevron_left, size: 18, color: Colors.white),
              ),
              Text(
                'LEVEL 01 · LYRA',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              Row(children: [
                _circleButton(
                  onTap: () {},
                  child: const Icon(Icons.pause, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 6),
                _circleButton(
                  onTap: widget.onFeedback,
                  child: const Icon(Icons.mail_outline, size: 14, color: Colors.white),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ValueListenableBuilder<({int score, int best})>(
                  valueListenable: widget.game.scoreNotifier,
                  builder: (_, data, __) => _StatCard(
                    label: 'SCORE',
                    value: formatGameScore(data.score),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(label: 'MOVES', value: '∞'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Goal bar placeholder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GOAL',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 9,
                          letterSpacing: 1.5,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to match!',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Text(
        'TAP · SWAP · MATCH',
        style: GoogleFonts.ibmPlexMono(
          fontSize: 9,
          letterSpacing: 1.5,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _circleButton({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 9,
              letterSpacing: 1.5,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: kLyraAccent,
            ),
          ),
        ],
      ),
    );
  }
}
