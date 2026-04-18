import 'dart:async' show unawaited;
import 'dart:math';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/models/tile_type.dart';
import 'golden_test_helpers.dart';

void main() {
  testWidgets('post refill matches golden', (tester) async {
    suppressFlameRiverpodDisposeError();

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
    await tester.pump(const Duration(seconds: 3));

    final world = game.world;
    // Pre-swap board state: (0,7) and (1,7) are red; (3,7) is red (will move to (2,7)
    // after swap); (2,7) is blue (will move to (3,7) after swap).
    // After runSwap((2,7),(3,7)): grid becomes red,red,red,blue at row 7 → 3-in-a-row ✓
    world.grid[0][7] = TileType.red;
    world.grid[1][7] = TileType.red;
    world.grid[2][7] = TileType.blue;
    world.grid[3][7] = TileType.red;

    final tileA = world.tiles[2][7]!;
    final tileB = world.tiles[3][7]!;
    tileA.tileType = TileType.blue;
    tileB.tileType = TileType.red;

    unawaited(world.runSwap(tileA, tileB));

    // Pump through full cascade cycle.
    // Timing budget: 220 ms swap animation + 300 ms gravity + 300 ms refill = 820 ms
    // per cascade level. 1500 ms covers up to ~2 cascade levels for seed 42,
    // ensuring the board is fully settled after refill.
    await tester.pump(const Duration(milliseconds: 1500));

    // Confirm the full swap→match→fall→refill cycle completed and game returned to idle.
    expect(
      game.phase,
      GamePhase.idle,
      reason: 'runSwap should complete the full cascade and return to idle',
    );

    await expectLater(
      find.byKey(gameKey),
      matchesGoldenFile('goldens/post_refill.png'),
    );
  });
}
