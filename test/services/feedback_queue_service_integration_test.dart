import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cosmic_match/models/feedback_item.dart';
import 'package:cosmic_match/services/feedback_queue_service.dart';

FeedbackItem _item({
  String id = 'item-1',
  String description = 'Test feedback',
  bool uploaded = false,
  String? githubIssueUrl,
}) =>
    FeedbackItem(
      id: id,
      timestamp: DateTime(2026, 1, 1),
      description: description,
      screenshotBase64:
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
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
      final service = FeedbackQueueService();
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
      final service = FeedbackQueueService();
      final queue = await service.loadQueue();
      expect(queue, isEmpty);
    });

    test('enqueue multiple items — all returned by loadQueue', () async {
      final service = FeedbackQueueService();
      await service.enqueue(_item(id: 'a', description: 'First'));
      await service.enqueue(_item(id: 'b', description: 'Second'));
      await service.enqueue(_item(id: 'c', description: 'Third'));
      final queue = await service.loadQueue();
      expect(queue, hasLength(3));
      final ids = queue.map((i) => i.id).toSet();
      expect(ids, containsAll(['a', 'b', 'c']));
    });

    test('loadQueue skips items with tampered CRC', () async {
      final service = FeedbackQueueService();
      // Directly write a tampered entry into the box
      final box = await Hive.openBox('feedback_queue');
      await box.put('tampered-1', {
        'id': 'tampered-1',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
        'description': 'hacked',
        'screenshotBase64': 'abc',
        'uploaded': true,
        'githubIssueUrl': null,
        'crc': 0,
      });
      await box.close();

      final queue = await service.loadQueue();
      expect(queue, isEmpty);
    });

    test('markUploaded updates uploaded flag and sets issueUrl', () async {
      final service = FeedbackQueueService();
      await service.enqueue(_item(id: 'up-1'));

      await service.markUploaded('up-1', 'https://github.com/issues/42');

      final queue = await service.loadQueue();
      expect(queue, hasLength(1));
      expect(queue.first.uploaded, isTrue);
      expect(queue.first.githubIssueUrl, 'https://github.com/issues/42');
    });

    test('markUploaded preserves other fields unchanged', () async {
      final service = FeedbackQueueService();
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
      final service = FeedbackQueueService();
      await service.enqueue(_item(id: 'real-1'));
      // Should not throw or corrupt the queue
      await service.markUploaded('nonexistent', 'https://github.com/issues/1');
      final queue = await service.loadQueue();
      expect(queue, hasLength(1));
      expect(queue.first.id, 'real-1');
    });

    test('remove deletes the correct item', () async {
      final service = FeedbackQueueService();
      await service.enqueue(_item(id: 'del-1', description: 'Delete me'));
      await service.enqueue(_item(id: 'keep-1', description: 'Keep me'));

      await service.remove('del-1');

      final queue = await service.loadQueue();
      expect(queue, hasLength(1));
      expect(queue.first.id, 'keep-1');
    });

    test('remove on unknown id is a no-op', () async {
      final service = FeedbackQueueService();
      await service.enqueue(_item(id: 'item-1'));
      await service.remove('nonexistent');
      final queue = await service.loadQueue();
      expect(queue, hasLength(1));
    });
  });
}
