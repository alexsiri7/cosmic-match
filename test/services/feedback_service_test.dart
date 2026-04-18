import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cosmic_match/models/pending_feedback.dart';

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
      await Hive.deleteBoxFromDisk('feedback_queue');
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('enqueue and read back items from Hive box', () async {
      final box = await Hive.openBox('feedback_queue');
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
      final box = await Hive.openBox('feedback_queue');

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
}
