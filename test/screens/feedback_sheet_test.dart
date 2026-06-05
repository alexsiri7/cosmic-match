import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cosmic_match/core/constants.dart';
import 'package:cosmic_match/screens/feedback_sheet.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('FeedbackSheet submit', () {
    Future<void> openSheet(
      WidgetTester tester, {
      required Future<void> Function({
        required String type,
        required String message,
        required String screenshotB64,
      }) onSubmit,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFeedbackSheet(
                context,
                screenshotBytes: kTransparentPng,
                onSubmit: onSubmit,
                checkCooldown: () async => 0,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'submit button is disabled without consent and enabled with valid form',
        (tester) async {
      Future<void> noopSubmit({
        required String type,
        required String message,
        required String screenshotB64,
      }) async {}

      await openSheet(tester, onSubmit: noopSubmit);

      // Enter valid message but do NOT accept privacy checkbox
      await tester.enterText(
        find.byType(TextField),
        'A' * kMinFeedbackMessageLength,
      );
      await tester.pump();

      // Submit should be disabled (privacy not accepted)
      var submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Submit'),
      );
      expect(submitButton.onPressed, isNull,
          reason: 'Submit must be disabled without privacy consent');

      // Accept privacy checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Submit should now be enabled
      submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Submit'),
      );
      expect(submitButton.onPressed, isNotNull,
          reason: 'Submit must be enabled with valid message + privacy consent');
    });

    testWidgets('failed submit shows SnackBar and re-enables button',
        (tester) async {
      await openSheet(
        tester,
        onSubmit: ({
          required String type,
          required String message,
          required String screenshotB64,
        }) async {
          throw Exception('Network error');
        },
      );

      // Fill form
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.enterText(
        find.byType(TextField),
        'A' * kMinFeedbackMessageLength,
      );
      await tester.pump();

      // Tap Submit, then use runAsync to let the dart:ui image codec
      // future settle (it fails, which triggers the catch block).
      await tester.tap(find.text('Submit'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)));
      // Consume only known test-infrastructure exceptions (image codec / font
      // loading) that fire during runAsync in the test backend. Re-throw
      // anything unexpected so real regressions surface immediately.
      Object? ex;
      while ((ex = tester.takeException()) != null) {
        final msg = ex.toString();
        if (!msg.contains('Codec') &&
            !msg.contains('codec') &&
            !msg.contains('google_fonts') &&
            !msg.contains('font')) {
          fail('Unexpected exception during submit flow: $ex');
        }
      }
      await tester.pump();

      // SnackBar should appear with error message
      expect(
        find.text('Failed to send feedback — will retry when online.'),
        findsOneWidget,
      );

      // Submit button should be re-enabled (sheet still visible)
      expect(find.text('SEND FEEDBACK'), findsOneWidget);
      final submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Submit'),
      );
      expect(submitButton.onPressed, isNotNull);
    });
  });
}
