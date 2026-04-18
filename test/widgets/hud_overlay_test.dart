// Tests for HudOverlay: verifies initial display and reactive updates.
// Uses Match3Game directly (no Flame engine needed — HudOverlay only reads
// scoreNotifier via ValueListenableBuilder, which requires no widget tree embedding).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/services/feedback_service.dart';
import 'package:cosmic_match/widgets/hud_overlay.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('HudOverlay', () {
    testWidgets('displays initial score 0 and best 0', (tester) async {
      final game = Match3Game(progressService: null);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HudOverlay(game: game))),
      );
      // Both SCORE and BEST start at 0
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('updates when scoreNotifier fires', (tester) async {
      final game = Match3Game(progressService: null);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HudOverlay(game: game))),
      );
      game.scoreNotifier.value = (score: 1500, best: 1500);
      await tester.pump();
      expect(find.text('1500'), findsWidgets);
    });

    testWidgets('shows score and best independently', (tester) async {
      final game = Match3Game(progressService: null);
      game.scoreNotifier.value = (score: 300, best: 900);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HudOverlay(game: game))),
      );
      await tester.pump();
      expect(find.text('300'), findsOneWidget);
      expect(find.text('900'), findsOneWidget);
    });

    testWidgets('feedback FAB hidden when feedbackService is null', (tester) async {
      final game = Match3Game(progressService: null);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HudOverlay(game: game))),
      );
      expect(find.byIcon(Icons.feedback_outlined), findsNothing);
    });

    testWidgets('feedback FAB visible when feedbackService is provided', (tester) async {
      final game = Match3Game(progressService: null);
      final service = FeedbackService(workerUrl: 'https://example.com/');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HudOverlay(game: game, feedbackService: service),
          ),
        ),
      );
      expect(find.byIcon(Icons.feedback_outlined), findsOneWidget);
      expect(find.byTooltip('Send Feedback'), findsOneWidget);
    });
  });
}
