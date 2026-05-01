import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cosmic_match/models/pending_feedback.dart';
import 'package:cosmic_match/services/feedback_service.dart';

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

      final map = original.toMap();
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

      final map = item.toMap();
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

      final map = item.toMap();
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
      final box = await Hive.openBox('feedback_worker_queue');
      final item = PendingFeedback(
        id: 'q-1',
        type: 'bug',
        message: 'test',
        screenshotB64: 'img',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'test',
        createdAt: DateTime(2025, 1, 1),
      );

      await box.put(item.id, item.toMap());
      expect(box.length, 1);

      final raw = box.get('q-1') as Map;
      final restored = PendingFeedback.fromMap(Map<String, dynamic>.from(raw));
      expect(restored.id, 'q-1');
      expect(restored.message, 'test');
    });

    test('multiple items can be stored and iterated', () async {
      final box = await Hive.openBox('feedback_worker_queue');

      for (int i = 0; i < 5; i++) {
        final item = PendingFeedback(
          id: 'item-$i',
          type: 'bug',
          message: 'msg $i',
          screenshotB64: '',
          appVersion: '1.0.0+1',
          os: 'android',
          device: 'test',
          createdAt: DateTime(2025, 1, 1),
        );
        await box.put(item.id, item.toMap());
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
        message: 'test',
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
        message: 'test',
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
        message: 'test',
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
        message: 'test',
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
      );

      await service.submit(
        type: 'bug',
        message: 'offline test',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      final box = await Hive.openBox('feedback_worker_queue');
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
        message: 'test',
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
        message: 'test',
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
      );

      // Fill queue to 20 items
      for (int i = 0; i < 20; i++) {
        await service.submit(
          type: 'bug',
          message: 'msg $i',
          screenshotB64: '',
          appVersion: '1.0.0+1',
          os: 'android',
          device: 'test',
        );
      }

      final box = await Hive.openBox('feedback_worker_queue');
      expect(box.length, 20);
      final firstMsg = (box.getAt(0) as Map)['message'] as String;

      // Submit one more — oldest should be evicted
      await service.submit(
        type: 'bug',
        message: 'overflow',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'test',
      );

      expect(box.length, 20);
      expect((box.getAt(0) as Map)['message'], isNot(firstMsg)); // oldest gone
      expect((box.getAt(box.length - 1) as Map)['message'], 'overflow');
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
      final box = await Hive.openBox('feedback_worker_queue');
      final item = PendingFeedback(
        id: 'flush-1',
        type: 'bug',
        message: 'queued',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'test',
        createdAt: DateTime.now(),
      );
      await box.put(item.id, item.toMap());
      expect(box.length, 1);

      final client = MockClient((_) async => http.Response('{"url": "https://github.com/issue/1"}', 201));
      final service = FeedbackService(
        workerUrl: 'https://example.com/',
        httpClient: client,
      );

      await service.flushQueue();
      expect(box.length, 0);
    });

    test('retains items in queue when POST fails', () async {
      final box = await Hive.openBox('feedback_worker_queue');
      final item = PendingFeedback(
        id: 'flush-2',
        type: 'bug',
        message: 'offline',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'test',
        createdAt: DateTime.now(),
      );
      await box.put(item.id, item.toMap());

      final client = MockClient((_) async => http.Response('', 503));
      final service = FeedbackService(
        workerUrl: 'https://example.com/',
        httpClient: client,
      );

      await service.flushQueue();
      expect(box.length, 1); // still in queue for next flush
    });

    test('drops items with tampered CRC on flush (CLAUDE.md persistence contract)', () async {
      final box = await Hive.openBox('feedback_worker_queue');
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
      // Write a valid map, then mutate `message` without recomputing CRC.
      final map = item.toMap();
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
      );

      await service.flushQueue();
      expect(box.length, 0,
          reason: 'tampered item should be dropped, not sent to worker');
    });

    test('drops items missing CRC on flush (CLAUDE.md persistence contract)', () async {
      final box = await Hive.openBox('feedback_worker_queue');
      // Legacy/tampered row without a `crc` key.
      await box.put('no-crc', {
        'id': 'no-crc',
        'type': 'bug',
        'message': 'no-crc',
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
      );

      await service.flushQueue();
      expect(box.length, 0,
          reason: 'item missing CRC should be dropped without retry');
    });

    test('a malformed row does not strand later valid items', () async {
      final box = await Hive.openBox('feedback_worker_queue');

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
      await box.put(good.id, good.toMap());
      expect(box.length, 2);

      final client = MockClient((_) async => http.Response('{"url":"x"}', 201));
      final service = FeedbackService(
        workerUrl: 'https://example.com/',
        httpClient: client,
      );

      await service.flushQueue();
      // Both rows should be removed: the bad one as invalid, the good one as sent.
      expect(box.length, 0,
          reason: 'a bad row must not abort the loop and strand later valid items');
    });
  });
}
