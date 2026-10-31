import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/models/level_progress.dart';
import 'package:cosmic_match/screens/game_screen.dart';
import 'package:cosmic_match/services/progress_service.dart';

class _StoredBestProgressService extends ProgressService {
  _StoredBestProgressService(this.bestScore);

  final int bestScore;

  @override
  Future<LevelProgress> load(int level) async =>
      LevelProgress(level: level, starsEarned: 0, bestScore: bestScore);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('GameScreen button wiring', () {
    testWidgets('back button fires onBack', (tester) async {
      var backCalled = false;
      var feedbackCalled = false;

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: GameScreen(
            game: Match3Game(rng: Random(42)),
            onBack: () => backCalled = true,
            onFeedback: () => feedbackCalled = true,
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      expect(backCalled, isTrue);
      expect(feedbackCalled, isFalse);
    });

    testWidgets('feedback button fires onFeedback', (tester) async {
      var backCalled = false;
      var feedbackCalled = false;

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: GameScreen(
            game: Match3Game(rng: Random(42)),
            onBack: () => backCalled = true,
            onFeedback: () => feedbackCalled = true,
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.mail_outline));
      await tester.pump();

      expect(feedbackCalled, isTrue);
      expect(backCalled, isFalse);
    });
  });

  testWidgets('BEST card shows the stored best score on load', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: GameScreen(
          game: Match3Game(
            progressService: _StoredBestProgressService(1200),
            rng: Random(42),
          ),
          onBack: () {},
          onFeedback: () {},
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    // flame_riverpod queues a game-widget rebuild for the next frame; flush it
    // while mounted, or teardown's frame calls setState on the disposed state.
    await tester.pump();

    expect(find.text('BEST'), findsOneWidget);
    expect(find.text('1,200'), findsOneWidget);
  });
}
