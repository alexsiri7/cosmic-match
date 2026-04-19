import 'dart:io';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive/hive.dart';
import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/game/world/grid_world.dart';
import 'package:cosmic_match/models/tile_type.dart';
import 'package:cosmic_match/services/progress_service.dart';
import 'package:cosmic_match/main.dart';

/// Build an 8×8 testGrid.
/// Tiles [0][7], [1][7], [3][7] = red; [2][7] = blue.
/// Swapping (2,7) ↔ (3,7) creates [0][7],[1][7],[2][7] = red → 3-match.
List<List<TileType?>> _buildTestGrid() {
  final g = List.generate(
    GridWorld.cols,
    (_) => List<TileType?>.generate(GridWorld.rows, (_) => TileType.orange),
  );
  g[0][7] = TileType.red;
  g[1][7] = TileType.red;
  g[2][7] = TileType.blue;
  g[3][7] = TileType.red;
  return g;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ProgressService progressService;
  late Match3Game game;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_integration_');
    Hive.init(tempDir.path);
    progressService = ProgressService();
    game = Match3Game(
      progressService: progressService,
      testGrid: _buildTestGrid(),
    );
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('scripted 3-match: score increments, FSM returns to idle, score persists', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: CosmicMatchApp(
          progressService: progressService,
          gameOverride: game,
        ),
      ),
    );

    // Let the app render the home screen.
    await tester.pump(const Duration(seconds: 2));

    // Tap the play button to navigate to the game screen.
    await tester.tap(find.textContaining('PLAY'));
    await tester.pump(const Duration(seconds: 2));

    // The RiverpodAwareGameWidget should now be visible.
    final gameWidgetFinder = find.byType(RiverpodAwareGameWidget<Match3Game>);
    expect(gameWidgetFinder, findsOneWidget);

    final gameWidgetOrigin = tester.getTopLeft(gameWidgetFinder);

    // Compute world-space centers for tiles (2,7) and (3,7).
    final world = game.world;
    final centerA = world.tilePositionAt(2, 7);
    final centerB = world.tilePositionAt(3, 7);

    // Convert to screen-space (tilePositionAt returns top-left of tile in world coords).
    final tileSize = world.tileSize;
    final screenA = Offset(
      gameWidgetOrigin.dx + centerA.x + tileSize / 2,
      gameWidgetOrigin.dy + centerA.y + tileSize / 2,
    );
    final screenB = Offset(
      gameWidgetOrigin.dx + centerB.x + tileSize / 2,
      gameWidgetOrigin.dy + centerB.y + tileSize / 2,
    );

    // Tap tile A, wait for FSM to register, tap tile B.
    await tester.tapAt(screenA);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(screenB);

    // Pump through full cascade: swapping → matching → falling → cascading → idle.
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Assert score increased.
    expect(game.scoreNotifier.value.score, greaterThan(0));

    // Assert FSM returned to idle.
    expect(game.phase, GamePhase.idle);

    // Assert persistence: reload progress and check bestScore.
    final loaded = await progressService.load(1);
    expect(loaded.bestScore, greaterThan(0));
  });
}
