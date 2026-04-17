import 'dart:async' show unawaited;
import 'dart:math';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/models/tile_type.dart';

void main() {
  testWidgets('post match clear matches golden', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('setState() called after dispose()')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final gameKey = GlobalKey<RiverpodAwareGameWidgetState<Match3Game>>();
    final game = Match3Game(rng: Random(42));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: SizedBox(
            width: 1080,
            height: 2244,
            child: RiverpodAwareGameWidget(
              key: gameKey,
              game: game,
            ),
          ),
        ),
      ),
    );
    // Wait for Flame onLoad + initial cascade to settle
    await tester.pump(const Duration(seconds: 3));

    // Inject a guaranteed horizontal 3-in-a-row at (0,7), (1,7), (2,7)
    final world = game.world;
    world.grid[0][7] = TileType.red;
    world.grid[1][7] = TileType.red;
    world.grid[2][7] = TileType.red;
    world.grid[3][7] = TileType.blue;

    final tileA = world.tiles[2][7]!;
    final tileB = world.tiles[3][7]!;
    tileA.tileType = TileType.red;
    tileB.tileType = TileType.blue;

    unawaited(world.runSwap(tileA, tileB));

    // Pump through swap animation + clear + gravity
    await tester.pump(const Duration(milliseconds: 900));

    await expectLater(
      find.byKey(gameKey),
      matchesGoldenFile('goldens/post_match_clear.png'),
    );
  });
}
