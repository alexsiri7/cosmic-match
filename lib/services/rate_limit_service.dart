import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants.dart';
import '../core/logger.dart';

typedef RateLimitStatus = ({
  bool allowed,
  int cooldownSeconds,
  int hourlyRemaining,
  DateTime? hourlyWindowStart,
});

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
  final DateTime Function() _now;

  RateLimitService({
    @visibleForTesting Map<String, String>? testStorage,
    @visibleForTesting DateTime Function()? now,
  })  : _testStorage = testStorage,
        _now = now ?? DateTime.now;

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
            _now().difference(windowStart).inMinutes < 60) {
          return (count: storedCount, windowStart: windowStart);
        }
      } catch (e) {
        gameLogger.d('RateLimitService: malformed hour-window JSON — resetting', error: e);
      }
    }
    return (count: 0, windowStart: _now());
  }

  /// Check whether a submission is currently allowed.
  ///
  /// Returns a record with:
  /// - `allowed`: whether the submission may proceed
  /// - `cooldownSeconds`: seconds remaining until the cooldown expires (0 if none)
  /// - `hourlyRemaining`: submissions left in the current hourly window;
  ///   `-1` when the per-submission cooldown fired first (hourly window not checked)
  /// - `hourlyWindowStart`: start of the capped hourly window; null unless the
  ///   hourly cap is what refused the submission
  Future<RateLimitStatus> checkStatus() async {
    try {
      // --- Per-submission cooldown ---
      final lastMs = await _read(_keyLastSubmit);
      if (lastMs != null) {
        final last = int.tryParse(lastMs);
        if (last != null) {
          final elapsedSeconds = (_now().millisecondsSinceEpoch - last) ~/ 1000;
          if (elapsedSeconds < kFeedbackCooldownSeconds) {
            final remaining = kFeedbackCooldownSeconds - elapsedSeconds;
            return (
              allowed: false,
              cooldownSeconds: remaining,
              hourlyRemaining: -1,
              hourlyWindowStart: null,
            );
          }
        }
      }

      // --- Hourly cap ---
      final (:count, :windowStart) = await _readHourlyWindow();

      if (count >= kFeedbackMaxPerHour) {
        return (
          allowed: false,
          cooldownSeconds: 0,
          hourlyRemaining: 0,
          hourlyWindowStart: windowStart,
        );
      }

      return (
        allowed: true,
        cooldownSeconds: 0,
        hourlyRemaining: kFeedbackMaxPerHour - count,
        hourlyWindowStart: null,
      );
    } catch (e, stack) {
      gameLogger.w('RateLimitService.checkStatus: storage error — failing open',
          error: e, stackTrace: stack);
      return (
        allowed: true,
        cooldownSeconds: 0,
        hourlyRemaining: kFeedbackMaxPerHour,
        hourlyWindowStart: null,
      );
    }
  }

  /// Record a submission attempt — updates cooldown timestamp and hourly count.
  Future<void> recordSubmission() async {
    try {
      await _write(
        _keyLastSubmit,
        _now().millisecondsSinceEpoch.toString(),
      );

      final window = await _readHourlyWindow();
      await _write(
        _keyHourWindow,
        jsonEncode({
          'count': window.count + 1,
          'windowStart': window.windowStart.toIso8601String(),
        }),
      );
    } catch (e, stack) {
      gameLogger.w('RateLimitService.recordSubmission: storage error',
          error: e, stackTrace: stack);
    }
  }

  /// Seconds until a submission is allowed again (cooldown or hourly cap;
  /// 0 = allowed).
  Future<int> remainingCooldownSeconds() async {
    final status = await checkStatus();
    if (status.allowed) return 0;
    if (status.cooldownSeconds > 0) return status.cooldownSeconds;
    final windowStart = status.hourlyWindowStart;
    if (windowStart == null) return 0;
    return max(1, 3600 - _now().difference(windowStart).inSeconds);
  }
}
