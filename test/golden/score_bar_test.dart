import 'dart:async' show unawaited;
import 'dart:math';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';
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

    final (tileA, tileB) = setupForcedMatch(game);
    unawaited(game.world.runSwap(tileA, tileB));

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
