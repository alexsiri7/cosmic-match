import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:cosmic_match/main.dart';
import 'package:cosmic_match/models/level_progress.dart';
import 'package:cosmic_match/repositories/progress_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_widget_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LevelProgressAdapter());
    }
    final progressBox = await Hive.openBox<LevelProgress>('test_progress');
    final settingsBox = await Hive.openBox<dynamic>('test_settings');
    progressRepository = ProgressRepository(
      progressBox: progressBox,
      settingsBox: settingsBox,
    );
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('App renders home screen with title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CosmicMatchApp());

    expect(find.text('Cosmic Match'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
