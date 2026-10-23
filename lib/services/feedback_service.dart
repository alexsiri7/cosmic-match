import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate, HttpException;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/crc_integrity.dart';
import '../core/logger.dart';
import '../models/feedback_result.dart';
import '../models/pending_feedback.dart';
import 'rate_limit_service.dart';

/// The issue number in [url] when it names an issue in [kFeedbackIssuesRepo],
/// else null. The worker supplies the URL, so only a number in the expected
/// shape is kept and nothing else from the response reaches the user.
@visibleForTesting
int? feedbackIssueNumber(String? url) {
  if (url == null) return null;
  final match = RegExp(
    '^https://github\\.com/${RegExp.escape(kFeedbackIssuesRepo)}/issues/(\\d+)\$',
  ).firstMatch(url);
  return match == null ? null : int.tryParse(match.group(1)!);
}

class FeedbackService {
  static const _boxName = 'feedback_worker_queue';
  static const _maxQueueSize = 20;

  final String workerUrl;
  final http.Client _httpClient;
  final RateLimitService? _rateLimitService;
  final HiveAesCipher? _cipher;
  final List<int>? _hmacKey;
  final String _workerHmacSecret;
  final Timer Function(Duration, void Function()) _createTimer;
  final DateTime Function() _now;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _retryFlushTimer;
  bool _flushing = false;

  FeedbackService({
    required this.workerUrl,
    http.Client? httpClient,
    RateLimitService? rateLimitService,
    HiveAesCipher? cipher,
    List<int>? hmacKey,
    String workerHmacSecret = '',
    @visibleForTesting Timer Function(Duration, void Function())? createTimer,
    @visibleForTesting DateTime Function()? now,
  })  : _httpClient = httpClient ?? http.Client(),
        _rateLimitService = rateLimitService,
        _cipher = cipher,
        _hmacKey = hmacKey,
        _workerHmacSecret = workerHmacSecret,
        _createTimer = createTimer ?? Timer.new,
        _now = now ?? DateTime.now;

  Future<Box> _openBox() => Hive.openBox(_boxName, encryptionCipher: _cipher);

  Future<T?> _withBox<T>(
    String opLabel,
    Future<T> Function(Box box) action, {
    bool logGenericAsError = false,
  }) async {
    try {
      final box = await _openBox();
      return await action(box);
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackService.$opLabel: HiveError', error: e, stackTrace: stack);
    } catch (e, stack) {
      if (logGenericAsError) {
        gameLogger.e('FeedbackService.$opLabel failed', error: e, stackTrace: stack);
      } else {
        gameLogger.w('FeedbackService.$opLabel failed', error: e, stackTrace: stack);
      }
    }
    return null;
  }

  /// Start listening for connectivity changes to flush queued feedback.
  void listenConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) {
        if (!results.contains(ConnectivityResult.none)) {
          flushQueue();
        }
      },
      onError: (Object e, StackTrace s) {
        gameLogger.w('FeedbackService: connectivity stream error', error: e, stackTrace: s);
      },
    );
  }

  /// Cancel connectivity listener and any scheduled retry flush.
  void dispose() {
    _connectivitySub?.cancel();
    _retryFlushTimer?.cancel();
  }

  /// Submit feedback — attempts an immediate POST; queues locally on a
  /// retryable failure (network error, or an HTTP error other than
  /// 400/401/403) for [flushQueue]. An item the worker refused retryably is
  /// queued already backed off, with a flush scheduled for when it is due.
  ///
  /// The outcome is [FeedbackOutcome.sent] on 201, carrying the filed issue's
  /// number when the worker reports one in [kFeedbackIssuesRepo];
  /// [FeedbackOutcome.queued] when the item was stored for retry;
  /// [FeedbackOutcome.rateLimited] when the limiter refused before any POST;
  /// and [FeedbackOutcome.notSent] when the input or worker URL is invalid,
  /// the worker rejected it permanently (400/401/403), or it could not be
  /// stored for retry.
  Future<FeedbackResult> submit({
    required String type,
    required String message,
    required String screenshotB64,
    required String appVersion,
    required String os,
    required String device,
  }) async {
    // Log attempt (not content) for rate-limit analysis (SEC-RPT-008).
    gameLogger.d('FeedbackService.submit: attempt type=$type');
    if (await _rateLimitRefusal('submit') != null) {
      return (outcome: FeedbackOutcome.rateLimited, issueNumber: null);
    }

    if (workerUrl.isEmpty) {
      gameLogger.w('FeedbackService.submit: workerUrl is empty — skipping');
      return _notSent;
    }

    final trimmed = message.trim();
    final trimmedLen = trimmed.length;
    if (trimmedLen < kMinFeedbackMessageLength) {
      gameLogger.w(
        'FeedbackService.submit: message too short '
        '($trimmedLen < $kMinFeedbackMessageLength) — skipping',
      );
      return _notSent;
    }
    if (trimmedLen > kMaxFeedbackMessageLength) {
      gameLogger.w(
        'FeedbackService.submit: message too long '
        '($trimmedLen > $kMaxFeedbackMessageLength) — skipping',
      );
      return _notSent;
    }

    String effectiveScreenshot = screenshotB64;
    if (screenshotB64.length > kMaxScreenshotB64Bytes) {
      gameLogger.w(
        'FeedbackService.submit: screenshot exceeds ${kMaxScreenshotB64Bytes}B '
        '(actual=${screenshotB64.length}) — omitting screenshot',
      );
      effectiveScreenshot = '';
    }

    final item = PendingFeedback(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      message: trimmed,
      screenshotB64: effectiveScreenshot,
      appVersion: appVersion,
      os: os,
      device: device,
      createdAt: DateTime.now(),
    );

    // Every POST is charged, even one that fails and is queued; otherwise
    // toggling connectivity bypasses the limiter (#306).
    await _rateLimitService?.recordSubmission();
    final result = await _postToWorker(item);
    if (result.accepted) {
      return (outcome: FeedbackOutcome.sent, issueNumber: result.issueNumber);
    }
    if (result.done) return _notSent;
    if (!result.responded) {
      return await _enqueue(item) ? _queued : _notSent;
    }
    final backoff = _backedOff(item, result.retryAfter);
    if (!await _enqueue(backoff.item)) return _notSent;
    _scheduleRetryFlush(backoff.delay.inSeconds);
    return _queued;
  }

  static const FeedbackResult _notSent =
      (outcome: FeedbackOutcome.notSent, issueNumber: null);
  static const FeedbackResult _queued =
      (outcome: FeedbackOutcome.queued, issueNumber: null);

  /// Returns the limiter's refusal, or null when the POST may proceed.
  Future<RateLimitStatus?> _rateLimitRefusal(String opLabel) async {
    final rl = _rateLimitService;
    if (rl == null) return null;
    final status = await rl.checkStatus();
    if (status.allowed) return null;
    gameLogger.w(
      'FeedbackService.$opLabel: rate-limited — '
      'cooldown=${status.cooldownSeconds}s hourlyRemaining=${status.hourlyRemaining}',
    );
    return status;
  }

  /// Seconds until a submission is allowed again (cooldown or hourly cap;
  /// 0 = allowed).
  Future<int> remainingCooldownSeconds() async =>
      await _rateLimitService?.remainingCooldownSeconds() ?? 0;

  /// Flush queued items — called on connectivity change. Items still backing
  /// off are skipped. Each POST is rate-limited like a direct submission;
  /// once the limiter refuses, the remaining items stay queued. A cooldown
  /// refusal schedules another flush for when it expires, so the queue keeps
  /// draining without a further connectivity event; an hourly-cap refusal
  /// waits for the next one.
  ///
  /// The flush stops at the first retryable failure. A network error or
  /// timeout leaves the item as it was, to be retried on the next
  /// connectivity event. A retryable worker response backs the item off
  /// (honouring `Retry-After`) and schedules a flush for when it is due; after
  /// [kFeedbackMaxAttempts] such responses the item is dropped (#327).
  Future<void> flushQueue() async {
    if (_flushing) return;
    _flushing = true;
    gameLogger.d('FeedbackService.flushQueue');
    try {
      await _withBox('flushQueue', (box) async {
        final keys = box.keys.toList();
        for (final key in keys) {
          // Per-item try/catch: a single bad row must not strand the rest of the queue.
          try {
            final raw = box.get(key);
            if (raw == null || raw is! Map) {
              await box.delete(key);
              continue;
            }
            final map = Map<String, dynamic>.from(raw);
            if (!_isValid(map)) {
              gameLogger.w('FeedbackService.flushQueue: dropping invalid item key=$key');
              await box.delete(key);
              continue;
            }
            final item = PendingFeedback.fromMap(map);
            final due = item.nextRetryAt;
            if (due != null && due.isAfter(_now())) continue;
            final refusal = await _rateLimitRefusal('flushQueue');
            if (refusal != null) {
              _scheduleRetryFlush(refusal.cooldownSeconds);
              break;
            }
            await _rateLimitService?.recordSubmission();
            final result = await _postToWorker(item);
            if (result.done) {
              await box.delete(key);
              continue;
            }
            if (!result.responded) break;
            final backoff = _backedOff(item, result.retryAfter);
            if (backoff.item.attempts >= kFeedbackMaxAttempts) {
              gameLogger.w(
                'FeedbackService.flushQueue: dropping item key=$key '
                'after ${backoff.item.attempts} attempts',
              );
              await box.delete(key);
            } else {
              await box.put(key, backoff.item.toMap(_hmacKey));
              _scheduleRetryFlush(backoff.delay.inSeconds);
            }
            break;
          } catch (e, stack) {
            gameLogger.w('FeedbackService.flushQueue: per-item error key=$key',
                error: e, stackTrace: stack);
            // Do not abort the loop — continue with the next key.
          }
        }
      }, logGenericAsError: true);
    } finally {
      _flushing = false;
    }
  }

  void _scheduleRetryFlush(int cooldownSeconds) {
    if (cooldownSeconds <= 0) return;
    _retryFlushTimer?.cancel();
    _retryFlushTimer = _createTimer(Duration(seconds: cooldownSeconds), flushQueue);
  }

  /// [item] after one more retryable worker response, due again after
  /// exponential backoff from [kFeedbackRetryBaseSeconds]. [retryAfter] can
  /// only lengthen the delay; [kFeedbackRetryMaxSeconds] bounds it.
  ({PendingFeedback item, Duration delay}) _backedOff(
    PendingFeedback item,
    Duration? retryAfter,
  ) {
    final attempts = item.attempts + 1;
    var seconds = kFeedbackRetryBaseSeconds << (attempts.clamp(1, 20) - 1);
    if (retryAfter != null && retryAfter.inSeconds > seconds) {
      seconds = retryAfter.inSeconds;
    }
    final delay = Duration(seconds: seconds.clamp(0, kFeedbackRetryMaxSeconds));
    return (item: item.afterFailedAttempt(_now().add(delay)), delay: delay);
  }

  /// A `Retry-After` value as delta-seconds or an HTTP-date; null when absent
  /// or unparseable.
  Duration? _parseRetryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) return seconds >= 0 ? Duration(seconds: seconds) : null;
    try {
      final wait = HttpDate.parse(value).difference(_now());
      return wait.isNegative ? Duration.zero : wait;
    } on HttpException {
      return null;
    }
  }

  // See CLAUDE.md "CRC32 Persistence Contract".
  bool _isValid(Map raw) {
    final key = _hmacKey;
    if (key == null) {
      gameLogger.w('FeedbackService._isValid: hmacKey unavailable — cannot validate integrity');
      return false;
    }
    return isValidHmac(raw, canonicalize: canonicalizeMap, key: key);
  }

  /// `done` is false when the item should be retried later; `accepted` is
  /// true only when the worker filed it (201). `responded` is false when the
  /// request itself failed (network error or timeout), so the worker saw no
  /// load; `retryAfter` is the worker's `Retry-After` on a retryable response.
  Future<({bool done, bool accepted, int? issueNumber, bool responded, Duration? retryAfter})>
      _postToWorker(PendingFeedback item) async {
    try {
      // `id` is stable across retries of the same queued item, so the signed
      // body identifies one submission and the worker can de-duplicate replays.
      final body = jsonEncode({
        'id': item.id,
        'repo': kFeedbackIssuesRepo,
        'type': item.type,
        'message': item.message,
        'screenshot': item.screenshotB64,
        'context': {
          'appVersion': item.appVersion,
          'os': item.os,
          'device': item.device,
        },
      });

      final headers = <String, String>{'Content-Type': 'application/json'};
      // Unsigned when no secret is configured (dev builds); the production worker
      // will reject these with 401 once it enforces signatures (see CM-024).
      if (_workerHmacSecret.isNotEmpty) {
        final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
        final sig = computeHmac('$ts.$body', utf8.encode(_workerHmacSecret));
        headers['X-Feedback-Timestamp'] = ts;
        headers['X-Feedback-Signature'] = 'sha256=$sig';
      }

      final response = await _httpClient
          .post(
            Uri.parse(workerUrl),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        // Best-effort: extract issue URL for logs, but never let a body-parse
        // failure flip a confirmed 201 success into a retry (would create
        // duplicate GitHub issues on the next flush).
        String? issueUrl;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) issueUrl = decoded['url'] as String?;
        } catch (e) {
          gameLogger.d('FeedbackService: 201 body parse failed — treating as success', error: e);
        }
        gameLogger.i('FeedbackService: posted successfully. Issue: ${issueUrl ?? '(url unavailable)'}');
        return (done: true, accepted: true, issueNumber: feedbackIssueNumber(issueUrl), responded: true, retryAfter: null);
      }

      // 400 = bad body — permanent failure, do not retry
      if (response.statusCode == 400) {
        gameLogger.w('FeedbackService: worker returned 400 — dropping item');
        return (done: true, accepted: false, issueNumber: null, responded: true, retryAfter: null); // not retried
      }

      // 401/403 = auth failure — permanent, wrong HMAC key will never self-heal on retry
      if (response.statusCode == 401 || response.statusCode == 403) {
        gameLogger.e('FeedbackService: worker returned ${response.statusCode} — auth failure, dropping item (check FEEDBACK_HMAC_SECRET)');
        return (done: true, accepted: false, issueNumber: null, responded: true, retryAfter: null); // permanent — wrong key will never succeed on retry
      }

      gameLogger.w('FeedbackService: worker returned ${response.statusCode} — will retry');
      return (
        done: false,
        accepted: false,
        issueNumber: null,
        responded: true,
        retryAfter: _parseRetryAfter(response.headers['retry-after']),
      );
    } catch (e, stack) {
      gameLogger.w('FeedbackService: POST failed — queuing', error: e, stackTrace: stack);
      return (done: false, accepted: false, issueNumber: null, responded: false, retryAfter: null);
    }
  }

  /// Clear all queued feedback items.
  Future<bool> clearQueue() async {
    gameLogger.d('FeedbackService.clearQueue');
    final result = await _withBox<bool>('clearQueue', (box) async {
      await box.clear();
      gameLogger.i('FeedbackService.clearQueue: queue cleared');
      return true;
    });
    return result ?? false;
  }

  /// Remove items older than [ttlDays] or with invalid integrity.
  Future<void> expireOldItems(int ttlDays) async {
    gameLogger.d('FeedbackService.expireOldItems: ttlDays=$ttlDays');
    await _withBox('expireOldItems', (box) async {
      final cutoff = DateTime.now().subtract(Duration(days: ttlDays));
      final keysToDelete = <dynamic>[];
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw == null || raw is! Map) {
          keysToDelete.add(key);
          continue;
        }
        final map = Map<String, dynamic>.from(raw);
        if (!_isValid(map)) {
          keysToDelete.add(key);
          continue;
        }
        final item = PendingFeedback.fromMap(map);
        if (item.createdAt.isBefore(cutoff)) {
          keysToDelete.add(key);
        }
      }
      for (final key in keysToDelete) {
        await box.delete(key);
      }
      if (keysToDelete.isNotEmpty) {
        gameLogger.i('FeedbackService.expireOldItems: deleted ${keysToDelete.length} item(s)');
      }
    });
  }

  /// Returns whether [item] was persisted.
  Future<bool> _enqueue(PendingFeedback item) async {
    final hmacKey = _hmacKey;
    if (hmacKey == null) {
      gameLogger.w('FeedbackService._enqueue: hmacKey unavailable — skipping persist for id=${item.id}');
      return false;
    }
    final stored = await _withBox<bool>('_enqueue', (box) async {
      // Enforce max queue size — drop oldest if full
      while (box.length >= _maxQueueSize) {
        await box.deleteAt(0);
      }

      await box.put(item.id, item.toMap(hmacKey));
      gameLogger.d('FeedbackService: queued item ${item.id}');
      return true;
    }, logGenericAsError: true);
    return stored ?? false;
  }
}
