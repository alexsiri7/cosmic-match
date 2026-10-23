import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/crc_integrity.dart';
import '../core/logger.dart';
import '../models/feedback_result.dart';
import '../models/pending_feedback.dart';
import 'key_service.dart';
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
  final StorageKeys? _keys;
  final String _workerHmacSecret;
  final Timer Function(Duration, void Function()) _createTimer;
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
  })  : _httpClient = httpClient ?? http.Client(),
        _rateLimitService = rateLimitService,
        _keys = StorageKeys.of(cipher, hmacKey),
        _workerHmacSecret = workerHmacSecret,
        _createTimer = createTimer ?? Timer.new;

  /// Runs [action] on the encrypted queue box; returns null without opening
  /// the box when the storage keys are unavailable or on failure.
  Future<T?> _withBox<T>(
    String opLabel,
    Future<T> Function(Box box, List<int> hmacKey) action, {
    bool logGenericAsError = false,
  }) async {
    final keys = _keys;
    if (keys == null) {
      gameLogger.w('FeedbackService.$opLabel: storage keys unavailable — skipping');
      return null;
    }
    try {
      final box = await Hive.openBox(_boxName, encryptionCipher: keys.cipher);
      return await action(box, keys.hmacKey);
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
  /// 400/401/403) for [flushQueue].
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
    if (!result.done && await _enqueue(item)) {
      return (outcome: FeedbackOutcome.queued, issueNumber: null);
    }
    return _notSent;
  }

  static const FeedbackResult _notSent =
      (outcome: FeedbackOutcome.notSent, issueNumber: null);

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

  /// Flush queued items — called on connectivity change. Each POST is
  /// rate-limited like a direct submission; once the limiter refuses, the
  /// remaining items stay queued. A cooldown refusal schedules another flush
  /// for when it expires, so the queue keeps draining without a further
  /// connectivity event; an hourly-cap refusal waits for the next one.
  Future<void> flushQueue() async {
    if (_flushing) return;
    _flushing = true;
    gameLogger.d('FeedbackService.flushQueue');
    try {
      await _withBox('flushQueue', (box, hmacKey) async {
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
            if (!_isValid(map, hmacKey)) {
              gameLogger.w('FeedbackService.flushQueue: dropping invalid item key=$key');
              await box.delete(key);
              continue;
            }
            final item = PendingFeedback.fromMap(map);
            final refusal = await _rateLimitRefusal('flushQueue');
            if (refusal != null) {
              _scheduleRetryFlush(refusal.cooldownSeconds);
              break;
            }
            await _rateLimitService?.recordSubmission();
            final result = await _postToWorker(item);
            if (result.done) {
              await box.delete(key);
            }
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

  bool _isValid(Map raw, List<int> hmacKey) =>
      isValidHmac(raw, canonicalize: canonicalizeMap, key: hmacKey);

  /// `done` is false when the item should be retried later; `accepted` is
  /// true only when the worker filed it (201).
  Future<({bool done, bool accepted, int? issueNumber})> _postToWorker(PendingFeedback item) async {
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
        return (done: true, accepted: true, issueNumber: feedbackIssueNumber(issueUrl));
      }

      // 400 = bad body — permanent failure, do not retry
      if (response.statusCode == 400) {
        gameLogger.w('FeedbackService: worker returned 400 — dropping item');
        return (done: true, accepted: false, issueNumber: null); // not retried
      }

      // 401/403 = auth failure — permanent, wrong HMAC key will never self-heal on retry
      if (response.statusCode == 401 || response.statusCode == 403) {
        gameLogger.e('FeedbackService: worker returned ${response.statusCode} — auth failure, dropping item (check FEEDBACK_HMAC_SECRET)');
        return (done: true, accepted: false, issueNumber: null); // permanent — wrong key will never succeed on retry
      }

      gameLogger.w('FeedbackService: worker returned ${response.statusCode} — will retry');
      return (done: false, accepted: false, issueNumber: null);
    } catch (e, stack) {
      gameLogger.w('FeedbackService: POST failed — queuing', error: e, stackTrace: stack);
      return (done: false, accepted: false, issueNumber: null);
    }
  }

  /// Clear all queued feedback items.
  Future<bool> clearQueue() async {
    gameLogger.d('FeedbackService.clearQueue');
    final result = await _withBox<bool>('clearQueue', (box, _) async {
      await box.clear();
      gameLogger.i('FeedbackService.clearQueue: queue cleared');
      return true;
    });
    return result ?? false;
  }

  /// Remove items older than [ttlDays] or with invalid integrity.
  Future<void> expireOldItems(int ttlDays) async {
    gameLogger.d('FeedbackService.expireOldItems: ttlDays=$ttlDays');
    await _withBox('expireOldItems', (box, hmacKey) async {
      final cutoff = DateTime.now().subtract(Duration(days: ttlDays));
      final keysToDelete = <dynamic>[];
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw == null || raw is! Map) {
          keysToDelete.add(key);
          continue;
        }
        final map = Map<String, dynamic>.from(raw);
        if (!_isValid(map, hmacKey)) {
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
    final stored = await _withBox<bool>('_enqueue', (box, hmacKey) async {
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
