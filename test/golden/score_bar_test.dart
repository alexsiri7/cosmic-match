import 'dart:math';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';

void main() {
  testWidgets('score bar position and text matches golden', (tester) async {
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
    await tester.pump(const Duration(seconds: 2));
    await expectLater(
      find.byKey(gameKey),
      matchesGoldenFile('goldens/score_bar.png'),
    );
  });
}
