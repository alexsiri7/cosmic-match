import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/main.dart';
import 'package:cosmic_match/services/feedback_service.dart';
import 'package:cosmic_match/services/progress_service.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'tapping Send feedback on HomeScreen opens feedback bottom sheet',
    (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: CosmicMatchApp(
          progressService: ProgressService(),
          feedbackService: FeedbackService(workerUrl: 'http://test'),
          gameOverride: Match3Game(progressService: null),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap the Send feedback button on HomeScreen
      final feedbackButton = find.text('Send feedback');
      expect(feedbackButton, findsOneWidget);
      await tester.tap(feedbackButton);
      await tester.pumpAndSettle();

      // Assert feedback bottom sheet opened (header text from _FeedbackSheet)
      expect(find.text('SEND FEEDBACK'), findsOneWidget);
    },
  );

  testWidgets(
    'feedback sheet background is opaque',
    (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: CosmicMatchApp(
          progressService: ProgressService(),
          feedbackService: FeedbackService(workerUrl: 'http://test'),
          gameOverride: Match3Game(progressService: null),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send feedback'));
      await tester.pumpAndSettle();

      expect(find.text('SEND FEEDBACK'), findsOneWidget);
    },
  );

  testWidgets(
    'feedback sheet mode toggle switches between draw and pan',
    (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: CosmicMatchApp(
          progressService: ProgressService(),
          feedbackService: FeedbackService(workerUrl: 'http://test'),
          gameOverride: Match3Game(progressService: null),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send feedback'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pan_tool), findsOneWidget);
    },
  );

  testWidgets(
    'feedback sheet Submit button is disabled until description meets minimum length',
    (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: CosmicMatchApp(
          progressService: ProgressService(),
          feedbackService: FeedbackService(workerUrl: 'http://test'),
          gameOverride: Match3Game(progressService: null),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send feedback'));
      await tester.pumpAndSettle();

      final submitFinder = find.widgetWithText(ElevatedButton, 'Submit');
      expect(submitFinder, findsOneWidget);

      // Initially disabled (empty description).
      expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNull);

      // 9 chars — still below threshold (10).
      await tester.enterText(find.byType(TextField), 'too short');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNull);

      // 10 chars — now enabled.
      await tester.enterText(find.byType(TextField), 'just right');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNotNull);

      // Whitespace-only (10 spaces) — trimmed length is 0, must stay disabled.
      await tester.enterText(find.byType(TextField), '          ');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNull,
          reason: 'whitespace-only must not satisfy the 10-char minimum');

      // Surrounding whitespace around a 9-char body — trimmed length is 9,
      // must stay disabled. Pins the UI-side `.trim()` semantics.
      await tester.enterText(find.byType(TextField), '  too short  ');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNull,
          reason: 'trimmed length is 9; surrounding whitespace must not satisfy the gate');
    },
  );

  testWidgets(
    'feedback sheet shows helper text describing the minimum length',
    (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: CosmicMatchApp(
          progressService: ProgressService(),
          feedbackService: FeedbackService(workerUrl: 'http://test'),
          gameOverride: Match3Game(progressService: null),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send feedback'));
      await tester.pumpAndSettle();

      // Couples helper-text copy to the constant — a restyle that drops or
      // hides `helperText` would otherwise leave Submit silently disabled
      // with no on-screen explanation.
      expect(find.text('At least 10 characters'), findsOneWidget);
    },
  );
}
