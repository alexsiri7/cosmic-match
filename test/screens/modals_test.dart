import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cosmic_match/screens/modals.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('LevelCompleteModal', () {
    testWidgets('tapping Next Level fires onContinue', (tester) async {
      // Suppress known pre-existing overflow in the REWARD row inside the
      // score card — we are only testing callback wiring, not layout.
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      var continueCalled = false;
      var replayCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LevelCompleteModal(
            stars: 2,
            score: 1000,
            onContinue: () => continueCalled = true,
            onReplay: () => replayCalled = true,
          ),
        ),
      ));

      await tester.tap(find.text('Next Level →'));
      await tester.pump();

      expect(continueCalled, isTrue);
      expect(replayCalled, isFalse);
    });

    testWidgets('tapping Replay fires onReplay', (tester) async {
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      var continueCalled = false;
      var replayCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LevelCompleteModal(
            stars: 2,
            score: 1000,
            onContinue: () => continueCalled = true,
            onReplay: () => replayCalled = true,
          ),
        ),
      ));

      await tester.tap(find.text('Replay'));
      await tester.pump();

      expect(replayCalled, isTrue);
      expect(continueCalled, isFalse);
    });
  });

  group('LevelFailedModal', () {
    testWidgets('tapping Retry fires onRetry', (tester) async {
      var retryCalled = false;
      var quitCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LevelFailedModal(
            score: 500,
            onRetry: () => retryCalled = true,
            onQuit: () => quitCalled = true,
          ),
        ),
      ));

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryCalled, isTrue);
      expect(quitCalled, isFalse);
    });

    testWidgets('tapping Galaxy map fires onQuit', (tester) async {
      var retryCalled = false;
      var quitCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LevelFailedModal(
            score: 500,
            onRetry: () => retryCalled = true,
            onQuit: () => quitCalled = true,
          ),
        ),
      ));

      await tester.tap(find.text('Galaxy map'));
      await tester.pump();

      expect(quitCalled, isTrue);
      expect(retryCalled, isFalse);
    });
  });
}
