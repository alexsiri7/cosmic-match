import 'dart:async' show unawaited;
import 'dart:math';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';
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

    final (tileA, tileB) = setupForcedMatch(game);
    unawaited(game.world.runSwap(tileA, tileB));

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
