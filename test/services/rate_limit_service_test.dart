import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/core/constants.dart';
import 'package:cosmic_match/services/rate_limit_service.dart';

void main() {
  group('RateLimitService', () {
    late Map<String, String> storage;
    late RateLimitService service;

    setUp(() {
      storage = {};
      service = RateLimitService(testStorage: storage);
    });

    test('checkStatus returns allowed when storage is empty', () async {
      final status = await service.checkStatus();
      expect(status.allowed, isTrue);
      expect(status.cooldownSeconds, 0);
      expect(status.hourlyRemaining, kFeedbackMaxPerHour);
    });

    test('checkStatus returns not-allowed when within cooldown window',
        () async {
      // Simulate a submission 10 seconds ago.
      storage['feedback_last_submit_ms'] =
          DateTime.now()
              .subtract(const Duration(seconds: 10))
              .millisecondsSinceEpoch
              .toString();

      final status = await service.checkStatus();
      expect(status.allowed, isFalse);
      expect(status.cooldownSeconds, greaterThan(0));
      expect(status.cooldownSeconds, lessThanOrEqualTo(20));
    });

    test('checkStatus returns allowed when cooldown has elapsed', () async {
      storage['feedback_last_submit_ms'] =
          DateTime.now()
              .subtract(const Duration(seconds: kFeedbackCooldownSeconds + 1))
              .millisecondsSinceEpoch
              .toString();

      final status = await service.checkStatus();
      expect(status.allowed, isTrue);
      expect(status.cooldownSeconds, 0);
    });

    test('checkStatus cooldownSeconds is the correct remaining value',
        () async {
      final submittedAt =
          DateTime.now().subtract(const Duration(seconds: 20));
      storage['feedback_last_submit_ms'] =
          submittedAt.millisecondsSinceEpoch.toString();

      final status = await service.checkStatus();
      // ~10 seconds remaining (30 - 20).
      expect(
          status.cooldownSeconds,
          allOf(greaterThanOrEqualTo(kFeedbackCooldownSeconds - 24),
              lessThanOrEqualTo(kFeedbackCooldownSeconds - 18)));
    });

    test('checkStatus returns not-allowed when hourly cap reached', () async {
      // No cooldown active.
      storage['feedback_last_submit_ms'] =
          DateTime.now()
              .subtract(const Duration(seconds: kFeedbackCooldownSeconds + 1))
              .millisecondsSinceEpoch
              .toString();
      // Hourly window with max submissions.
      storage['feedback_hour_window'] = jsonEncode({
        'count': kFeedbackMaxPerHour,
        'windowStart': DateTime.now()
            .subtract(const Duration(minutes: 30))
            .toIso8601String(),
      });

      final status = await service.checkStatus();
      expect(status.allowed, isFalse);
      expect(status.cooldownSeconds, 0);
      expect(status.hourlyRemaining, 0);
    });

    test('checkStatus returns allowed after hourly window resets', () async {
      // No cooldown.
      storage['feedback_last_submit_ms'] =
          DateTime.now()
              .subtract(const Duration(seconds: kFeedbackCooldownSeconds + 1))
              .millisecondsSinceEpoch
              .toString();
      // Stale window (older than 1 hour).
      storage['feedback_hour_window'] = jsonEncode({
        'count': kFeedbackMaxPerHour,
        'windowStart': DateTime.now()
            .subtract(const Duration(minutes: 61))
            .toIso8601String(),
      });

      final status = await service.checkStatus();
      expect(status.allowed, isTrue);
      expect(status.hourlyRemaining, kFeedbackMaxPerHour);
    });

    test('recordSubmission persists last-submit timestamp', () async {
      await service.recordSubmission();
      expect(storage.containsKey('feedback_last_submit_ms'), isTrue);
      final ms = int.parse(storage['feedback_last_submit_ms']!);
      expect(
        DateTime.now().millisecondsSinceEpoch - ms,
        lessThan(5000),
      );
    });

    test('recordSubmission increments hourly count', () async {
      await service.recordSubmission();
      final window =
          jsonDecode(storage['feedback_hour_window']!) as Map<String, dynamic>;
      expect(window['count'], 1);

      await service.recordSubmission();
      final window2 =
          jsonDecode(storage['feedback_hour_window']!) as Map<String, dynamic>;
      expect(window2['count'], 2);
    });

    test('recordSubmission resets hourly count when window is stale', () async {
      storage['feedback_hour_window'] = jsonEncode({
        'count': 4,
        'windowStart': DateTime.now()
            .subtract(const Duration(minutes: 61))
            .toIso8601String(),
      });

      await service.recordSubmission();
      final window =
          jsonDecode(storage['feedback_hour_window']!) as Map<String, dynamic>;
      expect(window['count'], 1);
    });

    test('checkStatus fails open on storage read error', () async {
      // Corrupt the last-submit value (non-numeric).
      storage['feedback_last_submit_ms'] = 'not-a-number';
      // Corrupt the hour window (non-JSON).
      storage['feedback_hour_window'] = '{broken';

      final status = await service.checkStatus();
      // Non-numeric lastMs is handled by int.tryParse returning null,
      // and broken JSON is caught — both should still allow.
      expect(status.allowed, isTrue);
    });

    test('remainingCooldownSeconds returns 0 when no cooldown active',
        () async {
      final secs = await service.remainingCooldownSeconds();
      expect(secs, 0);
    });

    test('remainingCooldownSeconds returns positive value when in cooldown',
        () async {
      storage['feedback_last_submit_ms'] =
          DateTime.now()
              .subtract(const Duration(seconds: 5))
              .millisecondsSinceEpoch
              .toString();

      final secs = await service.remainingCooldownSeconds();
      expect(secs, greaterThan(0));
      expect(secs, lessThanOrEqualTo(kFeedbackCooldownSeconds));
    });
  });
}
