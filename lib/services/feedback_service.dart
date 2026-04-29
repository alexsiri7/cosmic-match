import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../core/logger.dart';
import '../models/pending_feedback.dart';

class FeedbackService {
  static const _boxName = 'feedback_worker_queue';
  static const _maxQueueSize = 20;

  final String workerUrl;
  final http.Client _httpClient;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _flushing = false;

  FeedbackService({required this.workerUrl, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

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
    if (workerUrl.isEmpty) {
      gameLogger.w('FeedbackService.submit: workerUrl is empty — skipping');
      return;
    }

    gameLogger.d('FeedbackService.submit: type=$type');

    final item = PendingFeedback(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      message: message,
      screenshotB64: screenshotB64,
      appVersion: appVersion,
      os: os,
      device: device,
      createdAt: DateTime.now(),
    );

    final sent = await _postToWorker(item);
    if (!sent) {
      await _enqueue(item);
    }
  }

  /// Flush all queued items — called on connectivity change.
  Future<void> flushQueue() async {
    if (_flushing) return;
    _flushing = true;
    gameLogger.d('FeedbackService.flushQueue');
    try {
      final box = await Hive.openBox(_boxName);
      final keys = box.keys.toList();
      for (final key in keys) {
        final raw = box.get(key);
        if (raw == null || raw is! Map) {
          await box.delete(key);
          continue;
        }
        final item = PendingFeedback.fromMap(Map<String, dynamic>.from(raw));
        final sent = await _postToWorker(item);
        if (sent) {
          await box.delete(key);
        }
      }
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackService.flushQueue: HiveError', error: e, stackTrace: stack);
    } catch (e, stack) {
      gameLogger.w('FeedbackService.flushQueue failed', error: e, stackTrace: stack);
    } finally {
      _flushing = false;
    }
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
        final respBody = jsonDecode(response.body);
        gameLogger.i('FeedbackService: posted successfully. Issue: ${respBody['url']}');
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
    try {
      final box = await Hive.openBox(_boxName);

      // Enforce max queue size — drop oldest if full
      while (box.length >= _maxQueueSize) {
        await box.deleteAt(0);
      }

      await box.put(item.id, item.toMap());
      gameLogger.d('FeedbackService: queued item ${item.id}');
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackService._enqueue: HiveError', error: e, stackTrace: stack);
    } catch (e, stack) {
      gameLogger.w('FeedbackService._enqueue failed', error: e, stackTrace: stack);
    }
  }
}
