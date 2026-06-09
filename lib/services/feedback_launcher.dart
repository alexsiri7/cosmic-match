import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/constants.dart';
import '../core/logger.dart';
import '../screens/feedback_sheet.dart';
import 'feedback_service.dart';

/// Captures a screenshot and opens the feedback bottom sheet.
///
/// Shared by the home/game screen feedback button (via main.dart) and the
/// HUD overlay's in-game feedback button.
Future<void> launchFeedback({
  required BuildContext context,
  required FeedbackService service,
  required GlobalKey screenshotKey,
}) async {
  // Capture screenshot from RepaintBoundary
  Uint8List? screenshotBytes;
  try {
    final boundary = screenshotKey.currentContext?.findRenderObject()
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
    gameLogger.w('launchFeedback: screenshot capture failed',
        error: e, stackTrace: stack);
  }

  // Fall back to 1×1 transparent PNG so FeedbackSheet still opens.
  screenshotBytes ??= kTransparentPng;

  if (!context.mounted) return;

  showFeedbackSheet(
    context,
    screenshotBytes: screenshotBytes,
    checkCooldown: service.remainingCooldownSeconds,
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
