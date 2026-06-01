import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cosmic_match/core/constants.dart';
import 'package:cosmic_match/models/feedback_item.dart';
import 'package:cosmic_match/services/feedback_queue_service.dart';

final _testKey = List<int>.generate(32, (i) => i);

const _kTestPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

FeedbackItem _item({
  String id = 'item-1',
  String description = 'Test feedback',
  bool uploaded = false,
  String? githubIssueUrl,
  DateTime? timestamp,
}) =>
    FeedbackItem(
      id: id,
      timestamp: timestamp ?? DateTime(2026, 1, 1),
      description: description,
      screenshotBase64: _kTestPng,
      uploaded: uploaded,
      githubIssueUrl: githubIssueUrl,
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_feedback_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('FeedbackQueueService integration', () {
    test('enqueue → loadQueue round-trip preserves all fields', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      final original = _item(description: 'Round-trip check');
      await service.enqueue(original);
      final queue = await service.loadQueue();
      expect(queue, hasLength(1));
      expect(queue.first.id, original.id);
      expect(queue.first.description, original.description);
      expect(queue.first.screenshotBase64, original.screenshotBase64);
      expect(queue.first.uploaded, isFalse);
      expect(queue.first.githubIssueUrl, isNull);
    });

    test('loadQueue returns empty list when no items enqueued', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      final queue = await service.loadQueue();
      expect(queue, isEmpty);
    });

    test('enqueue multiple items — all returned by loadQueue', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      await service.enqueue(_item(id: 'a', description: 'First'));
      await service.enqueue(_item(id: 'b', description: 'Second'));
      await service.enqueue(_item(id: 'c', description: 'Third'));
      final queue = await service.loadQueue();
      expect(queue, hasLength(3));
      final ids = queue.map((i) => i.id).toSet();
      expect(ids, containsAll(['a', 'b', 'c']));
    });

    test('loadQueue skips items with tampered HMAC', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      // Directly write a tampered entry into the box
      final box = await Hive.openBox('feedback_queue');
      await box.put('tampered-1', {
        'id': 'tampered-1',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
        'description': 'hacked',
        'screenshotBase64': 'abc',
        'uploaded': true,
        'githubIssueUrl': null,
        'hmac': 'invalid',
      });
      await box.close();

      final queue = await service.loadQueue();
      expect(queue, isEmpty);
    });

    test('markUploaded updates uploaded flag and sets issueUrl', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      await service.enqueue(_item(id: 'up-1'));

      await service.markUploaded('up-1', 'https://github.com/issues/42');

      final queue = await service.loadQueue();
      expect(queue, hasLength(1));
      expect(queue.first.uploaded, isTrue);
      expect(queue.first.githubIssueUrl, 'https://github.com/issues/42');
    });

    test('markUploaded preserves other fields unchanged', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      final original = _item(id: 'up-2', description: 'Preserve me');
      await service.enqueue(original);

      await service.markUploaded('up-2', 'https://github.com/issues/99');

      final queue = await service.loadQueue();
      final item = queue.first;
      expect(item.description, original.description);
      expect(item.screenshotBase64, original.screenshotBase64);
      expect(item.id, original.id);
    });

    test('markUploaded on unknown id is a no-op', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      await service.enqueue(_item(id: 'real-1'));
      // Should not throw or corrupt the queue
      await service.markUploaded('nonexistent', 'https://github.com/issues/1');
      final queue = await service.loadQueue();
      expect(queue, hasLength(1));
      expect(queue.first.id, 'real-1');
    });

    test('remove deletes the correct item', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      await service.enqueue(_item(id: 'del-1', description: 'Delete me'));
      await service.enqueue(_item(id: 'keep-1', description: 'Keep me'));

      await service.remove('del-1');

      final queue = await service.loadQueue();
      expect(queue, hasLength(1));
      expect(queue.first.id, 'keep-1');
    });

    test('remove on unknown id is a no-op', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      await service.enqueue(_item(id: 'item-1'));
      await service.remove('nonexistent');
      final queue = await service.loadQueue();
      expect(queue, hasLength(1));
    });
  });

  group('expireOldItems', () {
    test('deletes items older than ttlDays', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      final box = await Hive.openBox('feedback_queue');
      final staleItem = FeedbackItem(
        id: 'stale-1',
        timestamp: DateTime.now().subtract(const Duration(days: 8)),
        description: 'Old feedback',
        screenshotBase64:
            _kTestPng,
      );
      await box.put(staleItem.id, staleItem.toMap(_testKey));
      await box.close();

      final deleted = await service.expireOldItems(7);

      expect(deleted, 1);
      final queue = await service.loadQueue();
      expect(queue, isEmpty);
    });

    test('keeps items within ttlDays', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      final freshItem = FeedbackItem(
        id: 'fresh-1',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        description: 'Recent feedback',
        screenshotBase64:
            _kTestPng,
      );
      await service.enqueue(freshItem);
      final deleted = await service.expireOldItems(7);
      expect(deleted, 0);
      final queue = await service.loadQueue();
      expect(queue, hasLength(1));
    });

    test('deletes expired but keeps fresh items', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      final freshItem = FeedbackItem(
        id: 'fresh-2',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        description: 'Recent feedback',
        screenshotBase64:
            _kTestPng,
      );
      await service.enqueue(freshItem);
      final box = await Hive.openBox('feedback_queue');
      final staleItem = FeedbackItem(
        id: 'stale-2',
        timestamp: DateTime.now().subtract(const Duration(days: 10)),
        description: 'Very old feedback',
        screenshotBase64:
            _kTestPng,
      );
      await box.put(staleItem.id, staleItem.toMap(_testKey));
      await box.close();

      final deleted = await service.expireOldItems(7);

      expect(deleted, 1);
      final queue = await service.loadQueue();
      expect(queue, hasLength(1));
      expect(queue.first.id, 'fresh-2');
    });

    test('also removes invalid/tampered entries', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      final box = await Hive.openBox('feedback_queue');
      await box.put('bad-hmac', {'id': 'bad-hmac', 'hmac': 'invalid'});
      await box.close();

      final deleted = await service.expireOldItems(7);
      expect(deleted, 1);
    });

    test('returns 0 on empty queue', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      final deleted = await service.expireOldItems(7);
      expect(deleted, 0);
    });

    test('keeps item aged exactly ttlDays minus one second (near-boundary: isBefore is strict)', () async {
      // Use ttlDays - 1 second as a safe proxy for the boundary to avoid a
      // wall-clock race: if we construct the item at exactly
      // DateTime.now().subtract(Duration(days: 7)), the cutoff computed inside
      // expireOldItems will be a few microseconds later, making the item appear
      // stale. Testing at ttlDays - 1 second pins the strictly-before semantics
      // without hitting the timing ambiguity.
      final service = FeedbackQueueService(hmacKey: _testKey);
      final nearBoundaryItem = FeedbackItem(
        id: 'near-boundary-ttl',
        timestamp: DateTime.now().subtract(
          const Duration(days: 7) - const Duration(seconds: 1),
        ),
        description: 'Just inside TTL boundary',
        screenshotBase64:
            _kTestPng,
      );
      await service.enqueue(nearBoundaryItem);
      final deleted = await service.expireOldItems(7);
      expect(deleted, 0,
          reason: 'item inside TTL window must not be deleted');
      final queue = await service.loadQueue();
      expect(queue, hasLength(1));
    });

    test('deletes item aged ttlDays + 1 second (one second past boundary)', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      final box = await Hive.openBox('feedback_queue');
      final pastItem = FeedbackItem(
        id: 'past-ttl',
        timestamp: DateTime.now().subtract(const Duration(days: 7, seconds: 1)),
        description: 'Just past TTL',
        screenshotBase64:
            _kTestPng,
      );
      await box.put(pastItem.id, pastItem.toMap(_testKey));
      await box.close();
      final deleted = await service.expireOldItems(7);
      expect(deleted, 1);
    });
  });

  group('constants', () {
    test('kFeedbackQueueTtlDays is 7 days (GDPR data-minimisation)', () {
      expect(kFeedbackQueueTtlDays, 7);
    });
  });

  group('clearAll', () {
    test('empties the entire queue', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      await service.enqueue(_item(id: 'c-1'));
      await service.enqueue(_item(id: 'c-2'));
      await service.enqueue(_item(id: 'c-3'));

      await service.clearAll();

      final queue = await service.loadQueue();
      expect(queue, isEmpty);
    });

    test('clearAll on empty queue is a no-op', () async {
      final service = FeedbackQueueService(hmacKey: _testKey);
      await service.clearAll();
      final queue = await service.loadQueue();
      expect(queue, isEmpty);
    });
  });

  group('FeedbackQueueService null-hmacKey fail-safe', () {
    test('enqueue with null hmacKey skips persist — loadQueue returns empty', () async {
      // Simulates secure storage failure: service constructed with hmacKey: null.
      final service = FeedbackQueueService(); // hmacKey: null
      await service.enqueue(_item(id: 'null-key-1'));

      final queue = await service.loadQueue();
      expect(queue, isEmpty,
          reason: 'enqueue skipped (null hmacKey) — queue must remain empty');
    });

    test('enqueue with null hmacKey writes nothing to the box', () async {
      final service = FeedbackQueueService(); // hmacKey: null
      await service.enqueue(_item(id: 'null-key-2'));

      final box = await Hive.openBox('feedback_queue');
      expect(box.get('null-key-2'), isNull,
          reason: 'null-key enqueue must not write any entry to the Hive box');
      await box.close();
    });
  });
}
