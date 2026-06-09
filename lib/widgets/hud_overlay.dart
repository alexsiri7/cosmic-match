import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/constants.dart';
import '../core/logger.dart';
import '../game/match3_game.dart';
import '../game/theme/cosmic_theme.dart';
import '../screens/feedback_sheet.dart';
import '../services/feedback_service.dart';
import 'stat_card.dart';

const _kCardFill = Color(0x0FFFFFFF);   // 6% white fill
const _kCardBorder = Color(0x1AFFFFFF); // 10% white border

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
    screenshotBytes ??= kTransparentPng;

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
          device: Platform.operatingSystemVersion.split(' ').first,
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
                  child: StatCard(label: 'SCORE',
                      value: scores.score.toString(),
                      accentColor: kCosmicAccent)),
              const SizedBox(width: 8),
              Expanded(
                  child: StatCard(label: 'BEST',
                      value: scores.best.toString(),
                      accentColor: kCosmicAccent)),
              if (feedbackService != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: IconButton(
                    onPressed: () => _onFeedbackTap(context),
                    icon: const Icon(Icons.feedback_outlined, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: _kCardFill,
                      side: const BorderSide(color: _kCardBorder),
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

