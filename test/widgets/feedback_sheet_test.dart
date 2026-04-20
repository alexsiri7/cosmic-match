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
}
