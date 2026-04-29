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
  });
}
