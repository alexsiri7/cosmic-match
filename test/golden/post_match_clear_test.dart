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
  testWidgets('post match clear matches golden', (tester) async {
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
    // Wait for Flame onLoad + initial cascade to settle
    await tester.pump(const Duration(seconds: 3));

    // Direct grid + tile mutation: force a known 3-in-a-row at columns 0-2, row 7
    // so the match is guaranteed regardless of the seeded board layout.
    // We set both the logical grid[] entries AND the visual tileType fields on the
    // GridTile components — both must agree for the match detector and swap animation
    // to behave correctly.
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

    // Pump to post-match-clear state (tiles removed, gravity in flight).
    // Timing budget: 220 ms swap animation → swap executes, matches cleared (sync)
    // → 300 ms gravity animation starts (completes at 520 ms).
    // At 500 ms the gravity animation is in progress but not settled; refill
    // (another 300 ms starting at 520 ms) has not begun yet.
    await tester.pump(const Duration(milliseconds: 500));

    // Verify we captured a mid-cascade state, not a fully settled board.
    expect(
      game.phase,
      isNot(GamePhase.idle),
      reason: 'Expected to capture post-clear state before cascade settles',
    );

    await expectLater(
      find.byKey(gameKey),
      matchesGoldenFile('goldens/post_match_clear.png'),
    );

    // Drain the remaining cascade timers so no pending timers are left when
    // the widget tree is disposed (Flutter test invariant).
    await tester.pump(const Duration(seconds: 2));
  });
}
