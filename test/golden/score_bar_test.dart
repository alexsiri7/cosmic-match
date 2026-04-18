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
  testWidgets('score bar displays non-zero score after match', (tester) async {
    suppressFlameRiverpodDisposeError();

    final gameKey = GlobalKey<RiverpodAwareGameWidgetState<Match3Game>>();
    // Use a different seed from the other golden tests so the initial board layout
    // and refilled tiles differ — ensuring score_bar.png is visually distinct from
    // post_refill.png (which uses seed 42).
    final game = Match3Game(rng: Random(99));
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

    // Pump through full cascade cycle so the score bar updates with a non-zero score.
    // Timing budget: 220 ms swap animation + 300 ms gravity + 300 ms refill = 820 ms
    // per cascade level. 1500 ms covers up to ~2 cascade levels for seed 99.
    await tester.pump(const Duration(milliseconds: 1500));

    // Confirm the cascade completed and score is non-zero (score bar shows earned points).
    expect(game.phase, GamePhase.idle,
        reason: 'Cascade should complete before capturing score bar state');
    expect(game.world.score.value, greaterThan(0),
        reason: 'Score must be non-zero so score bar is distinct from fresh_board');

    await expectLater(
      find.byKey(gameKey),
      matchesGoldenFile('goldens/score_bar.png'),
    );
  });
}
