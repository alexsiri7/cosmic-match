import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/main.dart';
import 'package:cosmic_match/screens/game_screen.dart';
import 'package:cosmic_match/screens/home_screen.dart';
import 'package:cosmic_match/services/feedback_service.dart';
import 'package:cosmic_match/services/progress_service.dart';

import 'golden/golden_test_helpers.dart';

class _FakeFeedbackService extends FeedbackService {
  _FakeFeedbackService({required this.clearResult}) : super(workerUrl: 'https://test');
  final bool clearResult;
  @override
  Future<bool> clearQueue() async => clearResult;
}

Future<void> pumpApp(WidgetTester tester, {FeedbackService? feedbackService}) async {
  await tester.pumpWidget(ProviderScope(
    child: CosmicMatchApp(
      progressService: ProgressService(),
      feedbackService: feedbackService,
      gameOverride: Match3Game(progressService: null),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Play opens GameScreen and Back returns to HomeScreen', (tester) async {
    suppressFlameRiverpodDisposeError();
    await pumpApp(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);

    await tester.tap(find.textContaining('PLAY LEVEL'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
  });

  testWidgets('clearing the feedback queue shows the cleared snackbar when the service succeeds',
      (tester) async {
    await pumpApp(tester, feedbackService: _FakeFeedbackService(clearResult: true));

    await tester.tap(find.text('Clear feedback queue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Feedback queue cleared'), findsOneWidget);
    expect(find.text('Could not clear queue'), findsNothing);
  });

  testWidgets(
      'clearing the feedback queue shows the failure snackbar when the service cannot clear',
      (tester) async {
    await pumpApp(tester, feedbackService: FeedbackService(workerUrl: 'https://test'));

    await tester.tap(find.text('Clear feedback queue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Could not clear queue'), findsOneWidget);
    expect(find.text('Feedback queue cleared'), findsNothing);
  });

  testWidgets('Send feedback does nothing when feedbackService is null', (tester) async {
    await pumpApp(tester, feedbackService: null);

    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();

    expect(find.text('SEND FEEDBACK'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('launchWithSentry launches exactly once when Sentry init throws', () async {
    var launches = 0;
    await launchWithSentry(
      initSentry: (_) async => throw StateError('boom'),
      launch: () => launches++,
    );
    expect(launches, 1);
  });

  test('launchWithSentry launches exactly once when Sentry init runs the app runner', () async {
    var launches = 0;
    await launchWithSentry(
      initSentry: (run) async => run(),
      launch: () => launches++,
    );
    expect(launches, 1);
  });
}
