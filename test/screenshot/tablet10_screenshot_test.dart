@Tags(['screenshots'])

import 'dart:async' show unawaited;
import 'dart:math';
import 'dart:ui' show Size;
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';
import '../golden/golden_test_helpers.dart';

// 10-inch tablet: 1600×2560 (Play Store spec)
const _w = 1600.0;
const _h = 2560.0;

void main() {
  testWidgets('tablet10_1 — fresh board (seed 42)', (tester) async {
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
      matchesGoldenFile('goldens/tablet10_1.png'),
    );
  });

  testWidgets('tablet10_2 — mid-cascade (match cleared, gravity in flight)', (tester) async {
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

    await expectLater(
      find.byKey(gameKey),
      matchesGoldenFile('goldens/tablet10_2.png'),
    );

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('tablet10_3 — post-refill settled board', (tester) async {
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

    await expectLater(
      find.byKey(gameKey),
      matchesGoldenFile('goldens/tablet10_3.png'),
    );
  });
}
