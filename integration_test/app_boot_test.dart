import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flame_riverpod/flame_riverpod.dart';

import 'package:cosmic_match/main.dart';
import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/services/progress_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('integ_boot_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('app cold-starts and renders grid within 5 s',
      (WidgetTester tester) async {
    final progressService = ProgressService();
    final game = Match3Game(progressService: progressService, rng: Random(0));

    await tester.pumpWidget(
      ProviderScope(
        child: CosmicMatchApp(
          progressService: progressService,
          game: game,
        ),
      ),
    );

    // Allow up to 5 s for Flame to finish onLoad
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(
      find.byType(RiverpodAwareGameWidget<Match3Game>),
      findsOneWidget,
      reason: 'GameWidget must be present in the widget tree',
    );
  });
}
