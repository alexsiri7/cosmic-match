@Tags(['screenshots'])
library;

import 'dart:async' show unawaited;
import 'dart:math';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';
import '../golden/golden_test_helpers.dart';

// Phone: 1080×1920 (Play Store spec)
const _w = 1080.0;
const _h = 1920.0;

void main() {
  testWidgets('phone_1 — fresh board (seed 42)', (tester) async {
    tester.view.physicalSize = const Size(_w, _h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    suppressFlameRiverpodDisposeError();

    final gameKey = GlobalKey<RiverpodAwareGameWidgetState<Match3Game>>();
    final game = Match3Game(rng: Random(42));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: SizedBox(
            width: _w,
            height: _h,
            child: RiverpodAwareGameWidget(
              key: gameKey,
              game: game,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await expectLater(
      find.byKey(gameKey),
      matchesGoldenFile('goldens/phone_1.png'),
    );
  });

  testWidgets('phone_2 — mid-cascade (match cleared, gravity in flight)', (tester) async {
    tester.view.physicalSize = const Size(_w, _h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    suppressFlameRiverpodDisposeError();

    final gameKey = GlobalKey<RiverpodAwareGameWidgetState<Match3Game>>();
    final game = Match3Game(rng: Random(42));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: SizedBox(
            width: _w,
            height: _h,
            child: RiverpodAwareGameWidget(
              key: gameKey,
              game: game,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    final (tileA, tileB) = setupForcedMatch(game);
    unawaited(game.world.runSwap(tileA, tileB));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      game.phase,
      isNot(GamePhase.idle),
      reason: 'phone_2 must capture mid-cascade, not a settled board',
    );

    await expectLater(
      find.byKey(gameKey),
      matchesGoldenFile('goldens/phone_2.png'),
    );

    // Drain remaining timers so widget teardown is clean.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('phone_3 — post-refill settled board', (tester) async {
    tester.view.physicalSize = const Size(_w, _h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    suppressFlameRiverpodDisposeError();

    final gameKey = GlobalKey<RiverpodAwareGameWidgetState<Match3Game>>();
    final game = Match3Game(rng: Random(42));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: SizedBox(
            width: _w,
            height: _h,
            child: RiverpodAwareGameWidget(
              key: gameKey,
              game: game,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    final (tileA, tileB) = setupForcedMatch(game);
    unawaited(game.world.runSwap(tileA, tileB));
    await tester.pump(const Duration(milliseconds: 1500));

    expect(
      game.phase,
      GamePhase.idle,
      reason: 'phone_3 must capture a settled board, not mid-cascade',
    );

    await expectLater(
      find.byKey(gameKey),
      matchesGoldenFile('goldens/phone_3.png'),
    );
  });
}
