import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cosmic_match/core/constants.dart';
import 'package:cosmic_match/models/pending_feedback.dart';
import 'package:cosmic_match/services/feedback_service.dart';
import 'package:cosmic_match/services/rate_limit_service.dart';

final _testKey = List<int>.generate(32, (i) => i);
final _testCipher = HiveAesCipher(List<int>.generate(32, (i) => i + 100));

void main() {
  group('PendingFeedback', () {
    test('toMap/fromMap round-trips correctly', () {
      final now = DateTime(2025, 1, 15, 10, 30);
      final original = PendingFeedback(
        id: 'test-1',
        type: 'bug',
        message: 'Something broke',
        screenshotB64: 'abc123',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel 7',
        createdAt: now,
      );

      final map = original.toMap(_testKey);
      final restored = PendingFeedback.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.message, original.message);
      expect(restored.screenshotB64, original.screenshotB64);
      expect(restored.appVersion, original.appVersion);
      expect(restored.os, original.os);
      expect(restored.device, original.device);
      expect(restored.createdAt, original.createdAt);
    });

    test('toMap stores createdAt as ISO 8601 string', () {
      final item = PendingFeedback(
        id: 'test-2',
        type: 'feature',
        message: 'Add dark mode',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel 7',
        createdAt: DateTime(2025, 3, 1),
      );

      final map = item.toMap(_testKey);
      expect(map['createdAt'], isA<String>());
      expect(DateTime.parse(map['createdAt'] as String), item.createdAt);
    });

    test('toMap includes all fields', () {
      final item = PendingFeedback(
        id: 'test-3',
        type: 'other',
        message: 'msg',
        screenshotB64: 'data',
        appVersion: '2.0.0+5',
        os: 'ios',
        device: 'iPhone 15',
        createdAt: DateTime(2025, 6, 1),
      );

      final map = item.toMap(_testKey);
      expect(map.keys, containsAll([
        'id', 'type', 'message', 'screenshotB64',
        'appVersion', 'os', 'device', 'createdAt',
      ]));
    });
  });

  group('FeedbackService queue (Hive)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('feedback_test_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('feedback_worker_queue');
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('enqueue and read back items from Hive box', () async {
      final box = await Hive.openBox('feedback_worker_queue', encryptionCipher: _testCipher);
      final item = PendingFeedback(
        id: 'q-1',
        type: 'bug',
        message: 'test message',
        screenshotB64: 'img',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'test',
        createdAt: DateTime(2025, 1, 1),
      );

      await box.put(item.id, item.toMap(_testKey));
      expect(box.length, 1);

      final raw = box.get('q-1') as Map;
      final restored = PendingFeedback.fromMap(Map<String, dynamic>.from(raw));
      expect(restored.id, 'q-1');
      expect(restored.message, 'test message');
    });

    test('multiple items can be stored and iterated', () async {
      final box = await Hive.openBox('feedback_worker_queue', encryptionCipher: _testCipher);

      for (int i = 0; i < 5; i++) {
        final item = PendingFeedback(
          id: 'item-$i',
          type: 'bug',
          message: 'queued msg $i',
          screenshotB64: '',
          appVersion: '1.0.0+1',
          os: 'android',
          device: 'test',
          createdAt: DateTime(2025, 1, 1),
        );
        await box.put(item.id, item.toMap(_testKey));
      }

      expect(box.length, 5);
      final keys = box.keys.toList();
      expect(keys, hasLength(5));
    });
  });

  group('FeedbackService.submit', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('submit_test_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('feedback_worker_queue');
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('does not enqueue when POST succeeds (201)', () async {
      final client = MockClient((_) async => http.Response('{"url": "https://github.com/issue/1"}', 201));
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
      );

      await service.submit(
        type: 'bug',
        message: 'test message',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      final box = await Hive.openBox('feedback_worker_queue');
      expect(box.length, 0);
    });

    test('treats 201 with empty body as success — does not enqueue', () async {
      // Regression guard: a 201 means the worker accepted the request, regardless
      // of body shape. If body parsing flipped a 201 to "failed", flushQueue would
      // re-POST and create a duplicate GitHub issue.
      final client = MockClient((_) async => http.Response('', 201));
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
      );

      await service.submit(
        type: 'bug',
        message: 'test message',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      final box = await Hive.openBox('feedback_worker_queue');
      expect(box.length, 0);
    });

    test('treats 201 with non-JSON body as success — does not enqueue', () async {
      final client = MockClient((_) async => http.Response('<html>OK</html>', 201));
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
      );

      await service.submit(
        type: 'bug',
        message: 'test message',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      final box = await Hive.openBox('feedback_worker_queue');
      expect(box.length, 0);
    });

    test('treats 201 with JSON missing url key as success — does not enqueue', () async {
      final client = MockClient((_) async => http.Response('{"id": 42}', 201));
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
      );

      await service.submit(
        type: 'bug',
        message: 'test message',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      final box = await Hive.openBox('feedback_worker_queue');
      expect(box.length, 0);
    });

    test('enqueues when POST fails (5xx)', () async {
      final client = MockClient((_) async => http.Response('', 503));
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
        cipher: _testCipher,
        hmacKey: _testKey,
      );

      await service.submit(
        type: 'bug',
        message: 'offline test',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      final box = await Hive.openBox('feedback_worker_queue', encryptionCipher: _testCipher);
      expect(box.length, 1);
    });

    test('does not retry on 400 response (permanent failure)', () async {
      final client = MockClient((_) async => http.Response('bad request', 400));
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
      );

      await service.submit(
        type: 'bug',
        message: 'test message',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'test',
      );

      final box = await Hive.openBox('feedback_worker_queue');
      expect(box.length, 0); // dropped, not queued
    });

    test('returns early without enqueue when workerUrl is empty', () async {
      final service = FeedbackService(workerUrl: '');

      await service.submit(
        type: 'bug',
        message: 'test message',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      final box = await Hive.openBox('feedback_worker_queue');
      expect(box.length, 0);
    });

    test('enforces 20-item cap — drops oldest when full', () async {
      final client = MockClient((_) async => http.Response('', 503));
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
        cipher: _testCipher,
        hmacKey: _testKey,
      );

      // Fill queue to 20 items
      for (int i = 0; i < 20; i++) {
        await service.submit(
          type: 'bug',
          message: 'queued msg $i',
          screenshotB64: '',
          appVersion: '1.0.0+1',
          os: 'android',
          device: 'test',
        );
      }

      final box = await Hive.openBox('feedback_worker_queue', encryptionCipher: _testCipher);
      expect(box.length, 20);
      final firstKey = box.keys.first;

      // Submit one more — oldest should be evicted
      await service.submit(
        type: 'bug',
        message: 'overflow item',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'test',
      );

      expect(box.length, 20);
      expect(box.get(firstKey), isNull); // oldest key evicted
      final lastKey = box.keys.last;
      expect((box.get(lastKey) as Map)['message'], 'overflow item');
    });

    test('skips POST and does not enqueue when message is too short', () async {
      var posted = false;
      final client = MockClient((_) async {
        posted = true;
        return http.Response('', 201);
      });
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
      );

      await service.submit(
        type: 'bug',
        message: 'too short', // 9 chars after trim
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      expect(posted, isFalse);
      final box = await Hive.openBox('feedback_worker_queue');
      expect(box.length, 0);
    });

    test('skips POST and does not enqueue when message is whitespace-only', () async {
      // Pins the trim() contract: 10 spaces trim to 0 chars and must be
      // rejected. Without this test, swapping `.trim().length` for `.length`
      // in the guard would slip past the suite.
      var posted = false;
      final client = MockClient((_) async {
        posted = true;
        return http.Response('', 201);
      });
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
      );

      await service.submit(
        type: 'bug',
        message: '          ', // 10 spaces — trims to 0
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      expect(posted, isFalse);
      final box = await Hive.openBox('feedback_worker_queue');
      expect(box.length, 0);
    });

    test('accepts message at the exact minimum length boundary', () async {
      // Pins the `<` boundary: an off-by-one regression to `<=` would silently
      // drop 10-char submissions that the UI accepts.
      var posted = false;
      final client = MockClient((_) async {
        posted = true;
        return http.Response('{"url": "https://github.com/issue/1"}', 201);
      });
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
      );

      await service.submit(
        type: 'bug',
        message: 'just right', // exactly 10 chars
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      expect(posted, isTrue);
      final box = await Hive.openBox('feedback_worker_queue');
      expect(box.length, 0);
    });

    test('does not POST and does not enqueue when rate-limited', () async {
      var posted = false;
      final client = MockClient((_) async {
        posted = true;
        return http.Response('{"url": "https://github.com/issue/1"}', 201);
      });

      // Simulate a submission 5 seconds ago (within the 30 s cooldown).
      final storage = <String, String>{
        'feedback_last_submit_ms': DateTime.now()
            .subtract(const Duration(seconds: 5))
            .millisecondsSinceEpoch
            .toString(),
      };
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
        rateLimitService: RateLimitService(testStorage: storage),
      );

      await service.submit(
        type: 'bug',
        message: 'rate limit test message',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      expect(posted, isFalse, reason: 'should not POST when rate-limited');
      final box = await Hive.openBox('feedback_worker_queue');
      expect(box.length, 0, reason: 'should not enqueue when rate-limited');
    });

    test('calls recordSubmission after successful POST (201)', () async {
      final client = MockClient(
          (_) async => http.Response('{"url": "https://github.com/issue/1"}', 201));

      // Cooldown already expired so submit is allowed.
      final storage = <String, String>{
        'feedback_last_submit_ms': DateTime.now()
            .subtract(const Duration(seconds: kFeedbackCooldownSeconds + 1))
            .millisecondsSinceEpoch
            .toString(),
      };
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
        rateLimitService: RateLimitService(testStorage: storage),
      );

      await service.submit(
        type: 'bug',
        message: 'submission that should count',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      // After a successful POST, a new cooldown must be active.
      final newSubmitMs = int.parse(storage['feedback_last_submit_ms']!);
      expect(
        DateTime.now().millisecondsSinceEpoch - newSubmitMs,
        lessThan(2000),
        reason: 'recordSubmission must update last-submit timestamp on 201',
      );
    });

    test('does not call recordSubmission when POST fails (503)', () async {
      final client = MockClient((_) async => http.Response('', 503));

      // Cooldown already expired.
      final originalMs = DateTime.now()
          .subtract(const Duration(seconds: kFeedbackCooldownSeconds + 1))
          .millisecondsSinceEpoch;
      final storage = <String, String>{
        'feedback_last_submit_ms': originalMs.toString(),
      };
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
        rateLimitService: RateLimitService(testStorage: storage),
        cipher: _testCipher,
        hmacKey: _testKey,
      );

      await service.submit(
        type: 'bug',
        message: 'failed submission message',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      // Timestamp must NOT have been updated (no recordSubmission call).
      expect(
        storage['feedback_last_submit_ms'],
        originalMs.toString(),
        reason: 'failed POST must not update the rate-limit timestamp',
      );
      // Item must be queued for retry.
      final box = await Hive.openBox('feedback_worker_queue', encryptionCipher: _testCipher);
      expect(box.length, 1);
    });

    test('rejects message longer than kMaxFeedbackMessageLength', () async {
      final capturedRequests = <http.Request>[];
      final client = MockClient((req) async {
        capturedRequests.add(req);
        return http.Response('{"url":"http://x"}', 201);
      });
      final service = FeedbackService(
        workerUrl: 'http://worker.test',
        httpClient: client,
        hmacKey: _testKey,
        cipher: _testCipher,
      );
      await service.submit(
        type: 'bug',
        message: 'x' * (kMaxFeedbackMessageLength + 1),
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );
      expect(capturedRequests, isEmpty,
          reason: 'oversized message must be rejected without making a network call');
    });

    test('accepts message at the exact maximum length boundary', () async {
      // Pins the `>` boundary: an off-by-one regression to `>=` would silently
      // drop 500-char submissions that the UI TextField permits.
      var posted = false;
      final client = MockClient((_) async {
        posted = true;
        return http.Response('{"url": "https://github.com/issue/1"}', 201);
      });
      final service = FeedbackService(
        workerUrl: 'http://worker.test',
        httpClient: client,
        hmacKey: _testKey,
        cipher: _testCipher,
      );

      await service.submit(
        type: 'bug',
        message: 'x' * kMaxFeedbackMessageLength, // exactly 500 chars
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      expect(posted, isTrue,
          reason: 'a message of exactly kMaxFeedbackMessageLength must be accepted');
    });

    test('omits screenshot when base64 exceeds kMaxScreenshotB64Bytes', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{"url":"http://x"}', 201);
      });
      final service = FeedbackService(
        workerUrl: 'http://worker.test',
        httpClient: client,
        hmacKey: _testKey,
        cipher: _testCipher,
      );
      final oversized = 'A' * (kMaxScreenshotB64Bytes + 1);
      await service.submit(
        type: 'bug',
        message: 'Valid feedback message',
        screenshotB64: oversized,
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );
      expect(captured, isNotNull, reason: 'submission should proceed (screenshot dropped)');
      final body = jsonDecode(captured!.body) as Map;
      expect(body['screenshot'], isEmpty,
          reason: 'oversized screenshot must be replaced with empty string');
    });

    test('passes through screenshot at exactly kMaxScreenshotB64Bytes', () async {
      // Pins the `>` boundary: an off-by-one regression to `>=` would silently
      // drop at-limit screenshots that are within the allowed threshold.
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{"url":"http://x"}', 201);
      });
      final service = FeedbackService(
        workerUrl: 'http://worker.test',
        httpClient: client,
        hmacKey: _testKey,
        cipher: _testCipher,
      );
      final atLimit = 'A' * kMaxScreenshotB64Bytes; // exactly at limit
      await service.submit(
        type: 'bug',
        message: 'Valid feedback message',
        screenshotB64: atLimit,
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );
      expect(captured, isNotNull);
      final body = jsonDecode(captured!.body) as Map;
      expect(
        (body['screenshot'] as String).length,
        kMaxScreenshotB64Bytes,
        reason: 'screenshot at exactly the limit must be sent unchanged',
      );
    });

    test('attaches X-Feedback-Signature header when workerHmacSecret is set', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{"url":"https://github.com/issue/1"}', 201);
      });
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
        workerHmacSecret: 'test-secret',
      );

      await service.submit(
        type: 'bug',
        message: 'message with signature',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      expect(captured, isNotNull);
      expect(
        captured!.headers.containsKey('x-feedback-signature'),
        isTrue,
        reason: 'POST must include X-Feedback-Signature when workerHmacSecret is set',
      );
      expect(captured!.headers['x-feedback-signature'], startsWith('sha256='));
    });

    test('does not attach X-Feedback-Signature when workerHmacSecret is empty', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{"url":"https://github.com/issue/1"}', 201);
      });
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
        // workerHmacSecret defaults to ''
      );

      await service.submit(
        type: 'bug',
        message: 'message without signature',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      expect(captured, isNotNull);
      expect(
        captured!.headers.containsKey('x-feedback-signature'),
        isFalse,
        reason: 'POST must omit X-Feedback-Signature when workerHmacSecret is empty',
      );
    });

    test('signature changes when body changes (HMAC correctness)', () async {
      final signatures = <String>[];
      final messages = ['first message here!', 'different message!!'];
      for (final msg in messages) {
        http.Request? captured;
        final client = MockClient((req) async {
          captured = req;
          return http.Response('{"url":"x"}', 201);
        });
        final service = FeedbackService(
          workerUrl: 'https://example.com/feedback',
          httpClient: client,
          workerHmacSecret: 'test-secret',
        );
        await service.submit(
          type: 'bug',
          message: msg,
          screenshotB64: '',
          appVersion: '1.0.0+1',
          os: 'android',
          device: 'Pixel',
        );
        signatures.add(captured!.headers['x-feedback-signature']!);
      }
      expect(signatures[0], isNot(equals(signatures[1])),
          reason: 'different bodies must produce different HMAC signatures');
    });

    test('sends correct POST body structure to worker', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"url": "https://github.com/issue/1"}', 201);
      });
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
      );

      await service.submit(
        type: 'bug',
        message: 'detailed bug report here',
        screenshotB64: 'base64img',
        appVersion: '2.0.0+3',
        os: 'android',
        device: 'Pixel 8',
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['repo'], 'alexsiri7/cosmic-match');
      expect(capturedBody!['type'], 'bug');
      expect(capturedBody!['message'], 'detailed bug report here');
      expect(capturedBody!['screenshot'], 'base64img');
      final context = capturedBody!['context'] as Map<String, dynamic>;
      expect(context['appVersion'], '2.0.0+3');
      expect(context['os'], 'android');
      expect(context['device'], 'Pixel 8');
    });
  });

  group('FeedbackService.remainingCooldownSeconds', () {
    test('returns 0 when no rateLimitService provided', () async {
      final service = FeedbackService(workerUrl: 'https://example.com/');
      expect(await service.remainingCooldownSeconds(), 0);
    });

    test('delegates to rateLimitService when provided', () async {
      final storage = <String, String>{
        'feedback_last_submit_ms': DateTime.now()
            .subtract(const Duration(seconds: 5))
            .millisecondsSinceEpoch
            .toString(),
      };
      final service = FeedbackService(
        workerUrl: 'https://example.com/',
        rateLimitService: RateLimitService(testStorage: storage),
      );
      final secs = await service.remainingCooldownSeconds();
      expect(secs, greaterThan(0));
      expect(secs, lessThanOrEqualTo(kFeedbackCooldownSeconds));
    });
  });

  group('FeedbackService.flushQueue', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flush_test_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('feedback_worker_queue');
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('removes successfully sent items from queue', () async {
      final box = await Hive.openBox('feedback_worker_queue', encryptionCipher: _testCipher);
      final item = PendingFeedback(
        id: 'flush-1',
        type: 'bug',
        message: 'queued',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'test',
        createdAt: DateTime(2025, 6, 1),
      );
      await box.put(item.id, item.toMap(_testKey));
      expect(box.length, 1);

      final client = MockClient((_) async => http.Response('{"url": "https://github.com/issue/1"}', 201));
      final service = FeedbackService(
        workerUrl: 'https://example.com/',
        httpClient: client,
        cipher: _testCipher,
        hmacKey: _testKey,
      );

      await service.flushQueue();
      expect(box.length, 0);
    });

    test('retains items in queue when POST fails', () async {
      final box = await Hive.openBox('feedback_worker_queue', encryptionCipher: _testCipher);
      final item = PendingFeedback(
        id: 'flush-2',
        type: 'bug',
        message: 'offline',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'test',
        createdAt: DateTime(2025, 6, 1),
      );
      await box.put(item.id, item.toMap(_testKey));

      final client = MockClient((_) async => http.Response('', 503));
      final service = FeedbackService(
        workerUrl: 'https://example.com/',
        httpClient: client,
        cipher: _testCipher,
        hmacKey: _testKey,
      );

      await service.flushQueue();
      expect(box.length, 1); // still in queue for next flush
    });

    test('drops items with tampered HMAC on flush (CLAUDE.md persistence contract)', () async {
      final box = await Hive.openBox('feedback_worker_queue', encryptionCipher: _testCipher);
      final item = PendingFeedback(
        id: 'tampered-1',
        type: 'bug',
        message: 'original',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'test',
        createdAt: DateTime(2025, 1, 1),
      );
      // Write a valid map, then mutate `message` without recomputing HMAC.
      final map = item.toMap(_testKey);
      map['message'] = 'tampered';
      await box.put(item.id, map);
      expect(box.length, 1);

      // POST should never be called — but if it were, the test would still
      // pass because the mock always returns 201. The assertion that matters
      // is that the tampered row is removed without being POSTed.
      final client = MockClient((_) async => http.Response('{"url":"x"}', 201));
      final service = FeedbackService(
        workerUrl: 'https://example.com/',
        httpClient: client,
        cipher: _testCipher,
        hmacKey: _testKey,
      );

      await service.flushQueue();
      expect(box.length, 0,
          reason: 'tampered item should be dropped, not sent to worker');
    });

    test('drops items missing HMAC on flush (CLAUDE.md persistence contract)', () async {
      final box = await Hive.openBox('feedback_worker_queue', encryptionCipher: _testCipher);
      // Legacy/tampered row without an `hmac` key.
      await box.put('no-hmac', {
        'id': 'no-hmac',
        'type': 'bug',
        'message': 'no-hmac',
        'screenshotB64': '',
        'appVersion': '1.0.0+1',
        'os': 'android',
        'device': 'test',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      });
      expect(box.length, 1);

      final client = MockClient((_) async => http.Response('{"url":"x"}', 201));
      final service = FeedbackService(
        workerUrl: 'https://example.com/',
        httpClient: client,
        cipher: _testCipher,
        hmacKey: _testKey,
      );

      await service.flushQueue();
      expect(box.length, 0,
          reason: 'item missing HMAC should be dropped without retry');
    });

    test('data written with cipher is not accessible without one (SEC-RPT-005 encryption-at-rest guard)', () async {
      // Guard: if cipher were silently dropped from _openBox(), Hive would store
      // data in plaintext and this test would fail — catching the regression.
      final client = MockClient((_) async => http.Response('', 503));
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: client,
        cipher: _testCipher,
        hmacKey: _testKey,
      );
      await service.submit(
        type: 'bug',
        message: 'encryption test message',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      // Flush all boxes so the encrypted file is fully written to disk.
      await Hive.close();

      // Re-opening the AES-encrypted box without the cipher must not expose data.
      // Hive returns an empty view when it cannot decrypt the frames, proving the
      // data is not accessible in plaintext (SEC-RPT-005 encryption-at-rest).
      final unencryptedView = await Hive.openBox('feedback_worker_queue');
      expect(
        unencryptedView.length,
        0,
        reason: 'Encrypted box must not expose data without the cipher (SEC-RPT-005)',
      );
    });

    test('a malformed row does not strand later valid items', () async {
      final box = await Hive.openBox('feedback_worker_queue', encryptionCipher: _testCipher);

      // Row 1: malformed createdAt — fromMap would throw.
      await box.put('bad', {
        'id': 'bad',
        'type': 'bug',
        'message': 'malformed',
        'screenshotB64': '',
        'appVersion': '1.0.0+1',
        'os': 'android',
        'device': 'test',
        'createdAt': 'not-a-date',
        // crc is wrong relative to canonicalised data, so _isValid drops it
        // before fromMap is reached anyway.
      });

      // Row 2: valid item.
      final good = PendingFeedback(
        id: 'good',
        type: 'bug',
        message: 'valid',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'test',
        createdAt: DateTime(2025, 1, 1),
      );
      await box.put(good.id, good.toMap(_testKey));
      expect(box.length, 2);

      final client = MockClient((_) async => http.Response('{"url":"x"}', 201));
      final service = FeedbackService(
        workerUrl: 'https://example.com/',
        httpClient: client,
        cipher: _testCipher,
        hmacKey: _testKey,
      );

      await service.flushQueue();
      // Both rows should be removed: the bad one as invalid, the good one as sent.
      expect(box.length, 0,
          reason: 'a bad row must not abort the loop and strand later valid items');
    });
  });

  group('FeedbackService null-hmacKey fail-safe', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_feedback_service_null_key_test_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('_enqueue with null hmacKey skips persist — flushQueue sees nothing', () async {
      // Simulates secure storage failure: FeedbackService constructed with hmacKey: null.
      // submit() will try to POST; on failure it calls _enqueue, which must be a no-op.
      final client = MockClient((_) async => throw Exception('network error'));
      final service = FeedbackService(
        workerUrl: 'https://example.com/',
        httpClient: client,
        // hmacKey: null — simulates storage failure
      );
      await service.submit(
        type: 'bug',
        message: 'test message for null key path',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'test',
      );

      final box = await Hive.openBox('feedback_worker_queue');
      expect(box.length, 0,
          reason: '_enqueue must skip write when hmacKey is null');
    });
  });
}
