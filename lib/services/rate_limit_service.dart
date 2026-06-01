import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants.dart';
import '../core/logger.dart';

/// Client-side rate limiter for feedback submissions (SEC-RPT-008).
///
/// Enforces a per-submission cooldown ([kFeedbackCooldownSeconds]) and an
/// hourly cap ([kFeedbackMaxPerHour]) using [FlutterSecureStorage].
/// On any storage error the limiter fails open — legitimate users are never
/// silently blocked due to a storage fault.
class RateLimitService {
  static const _keyLastSubmit = 'feedback_last_submit_ms';
  static const _keyHourWindow = 'feedback_hour_window';

  final Map<String, String>? _testStorage;
  final _storage = const FlutterSecureStorage();

  RateLimitService({@visibleForTesting Map<String, String>? testStorage})
      : _testStorage = testStorage;

  Future<String?> _read(String key) async {
    final ts = _testStorage;
    return ts != null ? ts[key] : await _storage.read(key: key);
  }

  Future<void> _write(String key, String value) async {
    final ts = _testStorage;
    if (ts != null) {
      ts[key] = value;
      return;
    }
    await _storage.write(key: key, value: value);
  }

  /// Reads the persisted hourly window. Returns `count=0, windowStart=now`
  /// when storage is empty, expired, or malformed.
  Future<({int count, DateTime windowStart})> _readHourlyWindow() async {
    final windowJson = await _read(_keyHourWindow);
    if (windowJson != null) {
      try {
        final map = jsonDecode(windowJson) as Map<String, dynamic>;
        final windowStart = DateTime.tryParse(map['windowStart'] as String? ?? '');
        final storedCount = map['count'] as int?;
        if (windowStart != null &&
            storedCount != null &&
            DateTime.now().difference(windowStart).inMinutes < 60) {
          return (count: storedCount, windowStart: windowStart);
        }
      } catch (e) {
        gameLogger.d('RateLimitService: malformed hour-window JSON — resetting', error: e);
      }
    }
    return (count: 0, windowStart: DateTime.now());
  }

  /// Check whether a submission is currently allowed.
  ///
  /// Returns a record with:
  /// - `allowed`: whether the submission may proceed
  /// - `cooldownSeconds`: seconds remaining until the cooldown expires (0 if none)
  /// - `hourlyRemaining`: submissions left in the current hourly window;
  ///   `-1` when the per-submission cooldown fired first (hourly window not checked)
  Future<({bool allowed, int cooldownSeconds, int hourlyRemaining})>
      checkStatus() async {
    try {
      // --- Per-submission cooldown ---
      final lastMs = await _read(_keyLastSubmit);
      if (lastMs != null) {
        final last = int.tryParse(lastMs);
        if (last != null) {
          final elapsed =
              DateTime.now().millisecondsSinceEpoch - last;
          final elapsedSeconds = elapsed ~/ 1000;
          if (elapsedSeconds < kFeedbackCooldownSeconds) {
            final remaining = kFeedbackCooldownSeconds - elapsedSeconds;
            return (
              allowed: false,
              cooldownSeconds: remaining,
              hourlyRemaining: -1,
            );
          }
        }
      }

      // --- Hourly cap ---
      final count = (await _readHourlyWindow()).count;

      if (count >= kFeedbackMaxPerHour) {
        return (allowed: false, cooldownSeconds: 0, hourlyRemaining: 0);
      }

      return (
        allowed: true,
        cooldownSeconds: 0,
        hourlyRemaining: kFeedbackMaxPerHour - count,
      );
    } catch (e, stack) {
      gameLogger.w('RateLimitService.checkStatus: storage error — failing open',
          error: e, stackTrace: stack);
      return (
        allowed: true,
        cooldownSeconds: 0,
        hourlyRemaining: kFeedbackMaxPerHour,
      );
    }
  }

  /// Record a successful submission — updates cooldown timestamp and hourly count.
  Future<void> recordSubmission() async {
    try {
      await _write(
        _keyLastSubmit,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Update hourly window.
      final window = await _readHourlyWindow();
      final count = window.count + 1;
      final windowStart = window.windowStart;
      await _write(
        _keyHourWindow,
        jsonEncode({
          'count': count,
          'windowStart': windowStart.toIso8601String(),
        }),
      );
    } catch (e, stack) {
      gameLogger.w('RateLimitService.recordSubmission: storage error',
          error: e, stackTrace: stack);
    }
  }

  /// Returns the remaining cooldown in seconds (0 = no cooldown active).
  Future<int> remainingCooldownSeconds() async {
    final status = await checkStatus();
    return status.cooldownSeconds;
  }
}
