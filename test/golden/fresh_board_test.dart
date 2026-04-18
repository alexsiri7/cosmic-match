import 'dart:math';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';

void main() {
  group('Golden – fresh board', () {
    testWidgets('renders deterministic initial board', (tester) async {
      // Suppress setState-after-dispose from flame_riverpod's
      // addPersistentFrameCallback (known library lifecycle issue in tests).
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('setState() called after dispose()')) {
          return;
        }
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final game = Match3Game(rng: Random(42));
      final gameKey = GlobalKey<RiverpodAwareGameWidgetState<Match3Game>>();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SizedBox(
              width: 1080,
              height: 2244,
              child: RiverpodAwareGameWidget(key: gameKey, game: game),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await expectLater(
        find.byType(RiverpodAwareGameWidget<Match3Game>),
        matchesGoldenFile('goldens/fresh_board.png'),
      );
    });
  });
}
