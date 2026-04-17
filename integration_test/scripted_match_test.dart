import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cosmic_match/main.dart';
import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/game/world/grid_world.dart';
import 'package:cosmic_match/services/progress_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ProgressService progressService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('integ_match_');
    Hive.init(tempDir.path);
    progressService = ProgressService();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets(
      'scripted swap produces score > 0, FSM returns to idle, score persists',
      (WidgetTester tester) async {
    // Seed 42 yields a board where swapping (0,0)↔(0,1) creates a 3-in-a-row.
    // Verified offline. Change seed and update comment if Flutter stdlib RNG changes.
    const boardSeed = 42;
    final game =
        Match3Game(progressService: progressService, rng: Random(boardSeed));

    await tester.pumpWidget(
      ProviderScope(
        child: CosmicMatchApp(
          progressService: progressService,
          game: game,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Compute screen coordinates for tile centers (0,0) and (0,1).
    final tileSize = game.world.tileSize;
    final screenW = game.size.x;
    final screenH = game.size.y;
    const cols = GridWorld.cols;
    const rows = GridWorld.rows;
    final boardOffsetX = (screenW - tileSize * cols) / 2;
    final boardOffsetY = 60.0 + (screenH - 60 - tileSize * rows) / 2;

    Offset tileCenter(int x, int y) => Offset(
          boardOffsetX + (x + 0.5) * tileSize,
          boardOffsetY + (y + 0.5) * tileSize,
        );

    // Tap tile (0,0) to select, then (0,1) to trigger swap.
    await tester.tapAt(tileCenter(0, 0));
    await tester.pump();
    await tester.tapAt(tileCenter(0, 1));

    // Wait for cascade to settle (FSM: swapping → matching → falling → idle).
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Assert: score increased from zero.
    expect(game.world.score.value, greaterThan(0),
        reason: 'A 3-match must have cleared and awarded points');

    // Assert: FSM returned to idle.
    expect(game.phase, GamePhase.idle,
        reason: 'Game must be ready for next interaction after cascade');

    // Assert: progress was persisted — reload and check bestScore.
    final loaded = await progressService.load(1);
    expect(loaded.bestScore, greaterThan(0),
        reason: 'Best score must be written to Hive after match');
  });
}
