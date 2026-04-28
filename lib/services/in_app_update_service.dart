import 'dart:io';

import 'package:in_app_update/in_app_update.dart';

import '../core/logger.dart';

class InAppUpdateService {
  Future<void> checkAndStartFlexibleUpdate({
    required void Function() onUpdateDownloaded,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        onUpdateDownloaded();
      }
    } catch (e, stack) {
      gameLogger.w('InAppUpdateService: update check failed', error: e, stackTrace: stack);
    }
  }

  Future<void> completeFlexibleUpdate() async {
    if (!Platform.isAndroid) return;
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e, stack) {
      gameLogger.w('InAppUpdateService: completeFlexibleUpdate failed', error: e, stackTrace: stack);
    }
  }
}
