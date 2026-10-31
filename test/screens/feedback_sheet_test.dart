import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cosmic_match/core/constants.dart';
import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/game/theme/cosmic_theme.dart';
import 'package:cosmic_match/main.dart';
import 'package:cosmic_match/models/feedback_result.dart';
import 'package:cosmic_match/screens/feedback_sheet.dart';
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
          feedbackService: FeedbackService(workerUrl: 'https://test'),
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
          feedbackService: FeedbackService(workerUrl: 'https://test'),
          gameOverride: Match3Game(progressService: null),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send feedback'));
      await tester.pumpAndSettle();

      final sheet = tester.widget<Container>(find.ancestor(
        of: find.text('SEND FEEDBACK'),
        matching: find.byWidgetPredicate(
            (w) => w is Container && (w.decoration as BoxDecoration?)?.gradient != null),
      ).last);
      expect((sheet.decoration! as BoxDecoration).gradient!.colors,
          [kCosmicNebulaA.withValues(alpha: 0.6), kCosmicInk]);
    },
  );

  testWidgets(
    'feedback sheet mode toggle switches between draw and pan',
    (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: CosmicMatchApp(
          progressService: ProgressService(),
          feedbackService: FeedbackService(workerUrl: 'https://test'),
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
          feedbackService: FeedbackService(workerUrl: 'https://test'),
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

      // 10 chars but checkbox not ticked — still disabled.
      await tester.enterText(find.byType(TextField), 'just right');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNull);

      // Tick privacy checkbox — now enabled.
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
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
          feedbackService: FeedbackService(workerUrl: 'https://test'),
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

  testWidgets(
    'Submit button disabled and countdown shown when cooldown is active',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => showFeedbackSheet(
                context,
                screenshotBytes: kTransparentPng,
                checkCooldown: () async => 15, // 15 seconds remaining
                onSubmit: ({required type, required message, required screenshotB64}) async => _sentResult,
              ),
              child: const Text('open'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Countdown text must be visible.
      expect(find.text('Try again in 15 seconds'), findsOneWidget);

      // Submit must be disabled even with sufficient text and privacy accepted.
      await tester.enterText(find.byType(TextField), 'just right now');
      await tester.pump();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      final btn = find.widgetWithText(ElevatedButton, 'Submit');
      expect(tester.widget<ElevatedButton>(btn).onPressed, isNull,
          reason:
              'active cooldown must disable Submit regardless of text length or privacy acceptance');
    },
  );

  testWidgets(
    'No countdown shown and Submit enabled when checkCooldown returns 0',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => showFeedbackSheet(
                context,
                screenshotBytes: kTransparentPng,
                checkCooldown: () async => 0,
                onSubmit: ({required type, required message, required screenshotB64}) async => _sentResult,
              ),
              child: const Text('open'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Try again'), findsNothing);

      // With no cooldown, sufficient text, and privacy accepted, button must be enabled.
      await tester.enterText(find.byType(TextField), 'just right now');
      await tester.pump();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      final btn = find.widgetWithText(ElevatedButton, 'Submit');
      expect(tester.widget<ElevatedButton>(btn).onPressed, isNotNull);
    },
  );

  testWidgets(
    'privacy notice is visible in feedback sheet',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => showFeedbackSheet(
                context,
                screenshotBytes: kTransparentPng,
                onSubmit: ({required type, required message, required screenshotB64}) async => _sentResult,
              ),
              child: const Text('open'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('will be sent to our server'), findsOneWidget);
      expect(find.textContaining('public GitHub repository'), findsOneWidget);
      expect(find.textContaining(kFeedbackIssuesRepo), findsOneWidget);
    },
  );

  testWidgets(
    'unchecking privacy checkbox re-disables Submit button',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => showFeedbackSheet(
                context,
                screenshotBytes: kTransparentPng,
                onSubmit: ({required type, required message, required screenshotB64}) async => _sentResult,
              ),
              child: const Text('open'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Enter sufficient text and tick checkbox → enabled.
      await tester.enterText(find.byType(TextField), 'just right now');
      await tester.pump();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      final btn = find.widgetWithText(ElevatedButton, 'Submit');
      expect(tester.widget<ElevatedButton>(btn).onPressed, isNotNull);

      // Untick checkbox → must go back to disabled.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(btn).onPressed, isNull,
          reason: 'unchecking privacy consent must re-disable Submit');
    },
  );

  testWidgets(
    'TextField has maxLength of kMaxFeedbackMessageLength',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => showFeedbackSheet(
                context,
                screenshotBytes: kTransparentPng,
                onSubmit: ({required type, required message, required screenshotB64}) async => _sentResult,
              ),
              child: const Text('open'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(
        textField.maxLength,
        kMaxFeedbackMessageLength,
        reason: 'UI must enforce the same cap as the service layer (SEC-RPT-003)',
      );
    },
  );

  testWidgets(
    'Submit button enabled after entering sufficient text and accepting privacy notice',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => showFeedbackSheet(
                context,
                screenshotBytes: kTransparentPng,
                onSubmit: ({required type, required message, required screenshotB64}) async => _sentResult,
              ),
              child: const Text('open'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'just right now');
      await tester.pump();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final btn = find.widgetWithText(ElevatedButton, 'Submit');
      expect(tester.widget<ElevatedButton>(btn).onPressed, isNotNull);
    },
  );

  group('FeedbackSheet submit', () {
    Future<void> openSheet(
      WidgetTester tester, {
      required Future<FeedbackResult> Function({
        required String type,
        required String message,
        required String screenshotB64,
      }) onSubmit,
      Future<int> Function() checkCooldown = _noCooldown,
      Uint8List? screenshotBytes,
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
                screenshotBytes: screenshotBytes ?? _decodablePng,
                onSubmit: onSubmit,
                checkCooldown: checkCooldown,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    Future<void> fillAndSubmit(WidgetTester tester, {String? text}) async {
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.enterText(
        find.byType(TextField),
        text ?? 'A' * kMinFeedbackMessageLength,
      );
      await tester.pump();

      // Tap Submit, then alternate real-async waits (for each dart:ui render
      // step) with pumps (to run its continuation in the test zone) until the
      // submit callback has settled.
      await tester.tap(find.text('Submit'));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
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
    }

    Future<FeedbackResult> Function({
      required String type,
      required String message,
      required String screenshotB64,
    }) answering(FeedbackOutcome outcome) => ({
          required String type,
          required String message,
          required String screenshotB64,
        }) async =>
            (outcome: outcome, issueNumber: null);

    testWidgets('failed submit shows the error in the sheet and re-enables button',
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

      await fillAndSubmit(tester);

      expect(find.text('Failed to send feedback.').hitTestable(), findsOneWidget);

      // Submit button should be re-enabled (sheet still visible)
      expect(find.text('SEND FEEDBACK'), findsOneWidget);
      final submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Submit'),
      );
      expect(submitButton.onPressed, isNotNull);
    });

    testWidgets('queued submit closes the sheet and says it will send later',
        (tester) async {
      await openSheet(tester, onSubmit: answering(FeedbackOutcome.queued));

      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('SEND FEEDBACK'), findsNothing);
      expect(
        find.textContaining(
          "Couldn't reach the server — your feedback will be sent "
          'automatically later.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'rate-limited submit keeps the sheet and text and shows the countdown',
        (tester) async {
      var cooldownChecks = 0;
      await openSheet(
        tester,
        onSubmit: answering(FeedbackOutcome.rateLimited),
        checkCooldown: () async => cooldownChecks++ == 0 ? 0 : 20,
      );

      await fillAndSubmit(tester, text: 'the board froze mid-cascade');

      expect(find.text('SEND FEEDBACK'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'the board froze mid-cascade',
      );
      expect(
        find
            .text('Too many reports — please wait before sending again.')
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Try again in 20 seconds'), findsOneWidget);
      final submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Submit'),
      );
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('not-sent submit keeps the sheet open and says so',
        (tester) async {
      await openSheet(tester, onSubmit: answering(FeedbackOutcome.notSent));

      await fillAndSubmit(tester);

      expect(find.text('SEND FEEDBACK'), findsOneWidget);
      expect(
        find.text("Feedback couldn't be sent.").hitTestable(),
        findsOneWidget,
      );
    });

    for (final (label, outcome, text) in [
      (
        'rate-limited',
        FeedbackOutcome.rateLimited,
        'Too many reports — please wait before sending again.',
      ),
      ('not-sent', FeedbackOutcome.notSent, "Feedback couldn't be sent."),
      ('failed', null, 'Failed to send feedback.'),
    ]) {
      testWidgets(
          '$label submit resolving after the sheet is dismissed still tells '
          'the player', (tester) async {
        final pending = Completer<FeedbackResult>();
        var submitted = false;
        await openSheet(
          tester,
          onSubmit: ({
            required String type,
            required String message,
            required String screenshotB64,
          }) {
            submitted = true;
            return pending.future;
          },
        );

        await fillAndSubmit(tester);
        expect(submitted, isTrue);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.text('SEND FEEDBACK'), findsNothing);

        if (outcome == null) {
          pending.completeError(Exception('Network error'));
        } else {
          pending.complete((outcome: outcome, issueNumber: null));
        }
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();

        expect(find.text(text), findsOneWidget);
      });
    }

    testWidgets(
        'oversized screenshot is dropped and the player is told it was not '
        'attached', (tester) async {
      final noisyPng = (await tester.runAsync(() => _noisyPng(1000, 1000)))!;
      String? sentScreenshot;
      await openSheet(
        tester,
        screenshotBytes: noisyPng,
        onSubmit: ({
          required String type,
          required String message,
          required String screenshotB64,
        }) async {
          sentScreenshot = screenshotB64;
          return _sentResult;
        },
      );

      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(sentScreenshot, isEmpty);
      expect(
        find.text("Feedback sent. The screenshot couldn't be attached."),
        findsOneWidget,
      );
    });

    testWidgets('shows privacy policy URL', (tester) async {
      await openSheet(tester, onSubmit: _noSubmit);

      expect(find.textContaining(kPrivacyPolicyUrl), findsOneWidget);
    });

    testWidgets('copy button puts privacy policy URL on clipboard',
        (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await openSheet(tester, onSubmit: _noSubmit);

      final copyButton = find.byTooltip('Copy privacy policy link');
      await tester.ensureVisible(copyButton);
      await tester.pumpAndSettle();
      await tester.tap(copyButton);
      await tester.pump();

      expect(copied, kPrivacyPolicyUrl);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}

const FeedbackResult _sentResult =
    (outcome: FeedbackOutcome.sent, issueNumber: null);

Future<FeedbackResult> _noSubmit({
  required String type,
  required String message,
  required String screenshotB64,
}) async =>
    _sentResult;

Future<int> _noCooldown() async => 0;

// Opaque random noise barely compresses, so its base64 PNG exceeds
// kMaxScreenshotB64Bytes once the sheet re-encodes it.
Future<Uint8List> _noisyPng(int width, int height) async {
  final random = Random(373);
  final pixels = Uint8List(width * height * 4);
  for (var i = 0; i < pixels.length; i++) {
    pixels[i] = i % 4 == 3 ? 0xFF : random.nextInt(256);
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
      pixels, width, height, ui.PixelFormat.rgba8888, completer.complete);
  final image = await completer.future;
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}

// A valid 1×1 transparent PNG, so the sheet's screenshot render succeeds and
// submit reaches `onSubmit`.
final _decodablePng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00,
  0x00, 0x05, 0x00, 0x01, 0x7A, 0x5E, 0xAB, 0x3F, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
