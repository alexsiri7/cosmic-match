import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/logger.dart';
import '../game/match3_game.dart';
import '../game/theme/cosmic_theme.dart';
import '../screens/feedback_sheet.dart';
import '../services/feedback_service.dart';

class HudOverlay extends StatelessWidget {
  final Match3Game game;
  final FeedbackService? feedbackService;
  final GlobalKey? screenshotKey;

  const HudOverlay({
    required this.game,
    this.feedbackService,
    this.screenshotKey,
    super.key,
  });

  Future<void> _onFeedbackTap(BuildContext context) async {
    final service = feedbackService;
    if (service == null || screenshotKey == null) return;

    // Capture screenshot from RepaintBoundary
    Uint8List? screenshotBytes;
    try {
      final boundary = screenshotKey!.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (byteData != null) {
          screenshotBytes = byteData.buffer.asUint8List();
        }
      }
    } catch (e, stack) {
      gameLogger.w('HudOverlay: screenshot capture failed', error: e, stackTrace: stack);
    }

    // If screenshot failed, use a 1x1 transparent PNG as placeholder
    screenshotBytes ??= Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02,
      0x00, 0x01, 0xE5, 0x27, 0xDE, 0xFC, 0x00, 0x00,
      0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
      0x60, 0x82,
    ]);

    if (!context.mounted) return;

    showFeedbackSheet(
      context,
      screenshotBytes: screenshotBytes,
      onSubmit: ({
        required String type,
        required String message,
        required String screenshotB64,
      }) async {
        final packageInfo = await PackageInfo.fromPlatform();
        await service.submit(
          type: type,
          message: message,
          screenshotB64: screenshotB64,
          appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
          os: Platform.operatingSystem,
          device: Platform.operatingSystemVersion,
        );
      },
    );
  }

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
                      value: scores.score.toString())),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatCard(label: 'BEST',
                      value: scores.best.toString())),
              if (feedbackService != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: IconButton(
                    onPressed: () => _onFeedbackTap(context),
                    icon: const Icon(Icons.feedback_outlined, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0x0FFFFFFF),
                      side: const BorderSide(color: Color(0x1AFFFFFF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    color: kCosmicAccent,
                    tooltip: 'Send Feedback',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

const _kCardFill = Color(0x0FFFFFFF);   // 6% white fill
const _kCardBorder = Color(0x1AFFFFFF); // 10% white border

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kCardFill,
        border: Border.all(color: _kCardBorder),
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
                color: kCosmicAccent)),
        ],
      ),
    );
  }
}
