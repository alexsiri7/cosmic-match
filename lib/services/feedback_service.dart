import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/crc_integrity.dart';
import '../core/logger.dart';
import '../models/pending_feedback.dart';
import 'rate_limit_service.dart';

class FeedbackService {
  static const _boxName = 'feedback_worker_queue';
  static const _maxQueueSize = 20;

  final String workerUrl;
  final http.Client _httpClient;
  final RateLimitService? _rateLimitService;
  final HiveAesCipher? _cipher;
  final List<int>? _hmacKey;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _flushing = false;

  FeedbackService({
    required this.workerUrl,
    http.Client? httpClient,
    RateLimitService? rateLimitService,
    HiveAesCipher? cipher,
    List<int>? hmacKey,
  })  : _httpClient = httpClient ?? http.Client(),
        _rateLimitService = rateLimitService,
        _cipher = cipher,
        _hmacKey = hmacKey;

  Future<Box> _openBox() => Hive.openBox(_boxName, encryptionCipher: _cipher);

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

  /// Cancel connectivity listener.
  void dispose() => _connectivitySub?.cancel();

  /// Submit feedback — attempts an immediate POST; queues locally on failure
  /// (network error or non-400 HTTP error) for retry on next connectivity event.
  Future<void> submit({
    required String type,
    required String message,
    required String screenshotB64,
    required String appVersion,
    required String os,
    required String device,
  }) async {
    // Log attempt (not content) for rate-limit analysis (SEC-RPT-008).
    gameLogger.d('FeedbackService.submit: attempt type=$type');
    final rl = _rateLimitService;
    if (rl != null) {
      final status = await rl.checkStatus();
      if (!status.allowed) {
        gameLogger.w(
          'FeedbackService.submit: rate-limited — '
          'cooldown=${status.cooldownSeconds}s hourlyRemaining=${status.hourlyRemaining}',
        );
        return;
      }
    }

    if (workerUrl.isEmpty) {
      gameLogger.w('FeedbackService.submit: workerUrl is empty — skipping');
      return;
    }

    final trimmed = message.trim();
    final trimmedLen = trimmed.length;
    if (trimmedLen < kMinFeedbackMessageLength) {
      gameLogger.w(
        'FeedbackService.submit: message too short '
        '($trimmedLen < $kMinFeedbackMessageLength) — skipping',
      );
      return;
    }
    if (trimmedLen > kMaxFeedbackMessageLength) {
      gameLogger.w(
        'FeedbackService.submit: message too long '
        '($trimmedLen > $kMaxFeedbackMessageLength) — skipping',
      );
      return;
    }

    final effectiveScreenshot = screenshotB64.length > kMaxScreenshotB64Bytes
        ? ''
        : screenshotB64;
    if (screenshotB64.length > kMaxScreenshotB64Bytes) {
      gameLogger.w(
        'FeedbackService.submit: screenshot exceeds ${kMaxScreenshotB64Bytes}B '
        '(actual=${screenshotB64.length}) — omitting screenshot',
      );
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

    final sent = await _postToWorker(item);
    if (sent) {
      await _rateLimitService?.recordSubmission();
    } else {
      await _enqueue(item);
    }
  }

  /// Returns the remaining cooldown in seconds (0 = no cooldown active).
  Future<int> remainingCooldownSeconds() async =>
      await _rateLimitService?.remainingCooldownSeconds() ?? 0;

  /// Flush all queued items — called on connectivity change.
  Future<void> flushQueue() async {
    if (_flushing) return;
    _flushing = true;
    gameLogger.d('FeedbackService.flushQueue');
    try {
      final box = await _openBox();
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
          final sent = await _postToWorker(item);
          if (sent) {
            await box.delete(key);
          }
        } catch (e, stack) {
          gameLogger.w('FeedbackService.flushQueue: per-item error key=$key',
              error: e, stackTrace: stack);
          // Do not abort the loop — continue with the next key.
        }
      }
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackService.flushQueue: HiveError', error: e, stackTrace: stack);
    } catch (e, stack) {
      gameLogger.e('FeedbackService.flushQueue failed', error: e, stackTrace: stack);
    } finally {
      _flushing = false;
    }
  }

  // See CLAUDE.md "CRC32 Persistence Contract".
  bool _isValid(Map raw) {
    final key = _hmacKey;
    if (key == null) {
      gameLogger.w('FeedbackService._isValid: hmacKey unavailable — cannot validate integrity');
      return false;
    }
    return isValidHmac(raw, canonicalize: PendingFeedback.canonicalize, key: key);
  }

  Future<bool> _postToWorker(PendingFeedback item) async {
    try {
      final body = jsonEncode({
        'repo': 'alexsiri7/cosmic-match',
        'type': item.type,
        'message': item.message,
        'screenshot': item.screenshotB64,
        'context': {
          'appVersion': item.appVersion,
          'os': item.os,
          'device': item.device,
        },
      });

      final response = await _httpClient
          .post(
            Uri.parse(workerUrl),
            headers: {'Content-Type': 'application/json'},
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
        return true;
      }

      // 400 = bad body — permanent failure, do not retry
      if (response.statusCode == 400) {
        gameLogger.w('FeedbackService: worker returned 400 — dropping item');
        return true; // treat as "done" so it is not retried
      }

      gameLogger.w('FeedbackService: worker returned ${response.statusCode} — will retry');
      return false;
    } catch (e, stack) {
      gameLogger.w('FeedbackService: POST failed — queuing', error: e, stackTrace: stack);
      return false;
    }
  }

  Future<void> _enqueue(PendingFeedback item) async {
    if (_hmacKey == null) {
      gameLogger.w('FeedbackService._enqueue: hmacKey unavailable — skipping persist for id=${item.id}');
      return;
    }
    try {
      final box = await _openBox();

      // Enforce max queue size — drop oldest if full
      while (box.length >= _maxQueueSize) {
        await box.deleteAt(0);
      }

      await box.put(item.id, item.toMap(_hmacKey));
      gameLogger.d('FeedbackService: queued item ${item.id}');
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackService._enqueue: HiveError', error: e, stackTrace: stack);
    } catch (e, stack) {
      gameLogger.e('FeedbackService._enqueue failed', error: e, stackTrace: stack);
    }
  }
}
