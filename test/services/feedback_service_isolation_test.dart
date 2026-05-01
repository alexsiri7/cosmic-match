import 'dart:io';

import 'package:cosmic_match/models/feedback_item.dart';
import 'package:cosmic_match/services/feedback_queue_service.dart';
import 'package:cosmic_match/services/feedback_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Regression guard for PR #132: `FeedbackService` and `FeedbackQueueService`
/// must use distinct Hive boxes. Before the box rename, both services shared
/// `feedback_queue` with incompatible map shapes; one would corrupt reads from
/// the other. The tests below assert runtime isolation — if a future refactor
/// re-aligns the box names, these tests fail.
void main() {
  group('FeedbackService / FeedbackQueueService Hive box isolation', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('isolation_test_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('feedback_queue');
      await Hive.deleteBoxFromDisk('feedback_worker_queue');
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('FeedbackQueueService writes do not appear in the worker-queue box', () async {
      final ghQueue = FeedbackQueueService();
      await ghQueue.enqueue(FeedbackItem(
        id: 'gh-1',
        timestamp: DateTime(2026, 1, 1),
        description: 'github-path message',
        screenshotBase64: '',
      ));

      final workerBox = await Hive.openBox('feedback_worker_queue');
      expect(
        workerBox.length,
        0,
        reason:
            'FeedbackService must not see FeedbackQueueService writes (PR #132 collision fix).',
      );
    });

    test('FeedbackService failure-enqueue does not appear in the GitHub-queue box', () async {
      final service = FeedbackService(
        workerUrl: 'https://example.com/feedback',
        httpClient: MockClient((_) async => http.Response('', 503)),
      );

      await service.submit(
        type: 'bug',
        message: 'worker-path message',
        screenshotB64: '',
        appVersion: '1.0.0+1',
        os: 'android',
        device: 'Pixel',
      );

      // The worker queue must hold the failed submission.
      final workerBox = await Hive.openBox('feedback_worker_queue');
      expect(workerBox.length, 1,
          reason: 'sanity: failure should enqueue into the worker-queue box');

      // The GitHub-path queue must be empty.
      final ghItems = await FeedbackQueueService().loadQueue();
      expect(
        ghItems,
        isEmpty,
        reason:
            'FeedbackQueueService must not see FeedbackService writes (PR #132 collision fix).',
      );
    });

  });
}
