import 'package:hive/hive.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../core/logger.dart';

/// Fires a one-shot Sentry "launch-smoke" message per install per buildNumber.
///
/// Purpose: after a new release rolls out, we want a single breadcrumb in
/// Sentry confirming the build was actually launched on a device and that
/// its debug-symbol upload / symbolication path is wired correctly.
///
/// The message fires exactly once per (install, buildNumber) pair. The last
/// buildNumber observed is persisted in a small Hive box so reinstalls also
/// re-fire the smoke test (a fresh install is a legitimate "did this build
/// actually launch" signal), while everyday cold starts do not spam Sentry.
class SentrySmokeService {
  static const _boxName = 'sentry_smoke';
  static const _key = 'last_smoke_build_number';

  /// Callable that sends the smoke message. Defaults to [Sentry.captureMessage]
  /// but is overridable in tests.
  final Future<void> Function(String message) _send;

  /// Opens the Hive box. Overridable in tests.
  final Future<Box<dynamic>> Function(String name) _openBox;

  SentrySmokeService({
    Future<void> Function(String message)? send,
    Future<Box<dynamic>> Function(String name)? openBox,
  })  : _send = send ?? _defaultSend,
        _openBox = openBox ?? _defaultOpenBox;

  static Future<void> _defaultSend(String message) =>
      Sentry.captureMessage(
        message,
        withScope: (scope) {
          scope.fingerprint = ['launch-smoke'];
        },
      );

  static Future<Box<dynamic>> _defaultOpenBox(String name) =>
      Hive.openBox<dynamic>(name);

  /// Fires a smoke message iff [buildNumber] differs from the last observed
  /// one. Returns `true` when a message was actually sent.
  ///
  /// Failures (Hive or Sentry) are swallowed and logged — a smoke test must
  /// never crash the app.
  Future<bool> maybeFire({
    required String version,
    required String buildNumber,
  }) async {
    try {
      final box = await _openBox(_boxName);
      try {
        final last = box.get(_key);
        if (last == buildNumber) {
          gameLogger.d(
              'SentrySmokeService: skipping, buildNumber=$buildNumber already smoke-tested');
          return false;
        }
        await _send('launch-smoke v$version+$buildNumber');
        await box.put(_key, buildNumber);
        gameLogger.i('SentrySmokeService: fired for $version+$buildNumber');
        return true;
      } finally {
        await box.close();
      }
    } catch (e, stack) {
      gameLogger.w('SentrySmokeService.maybeFire failed',
          error: e, stackTrace: stack);
      return false;
    }
  }
}
