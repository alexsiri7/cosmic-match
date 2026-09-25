import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cosmic_match/services/feedback_launcher.dart';
import 'package:cosmic_match/services/feedback_service.dart';

void main() {
  group('launchFeedback', () {
    testWidgets(
        'opens the sheet with the transparent-PNG fallback when no RepaintBoundary is attached',
        (tester) async {
      final service = FeedbackService(workerUrl: 'http://test');
      final screenshotKey = GlobalKey();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => launchFeedback(
                context: context,
                service: service,
                screenshotKey: screenshotKey,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('SEND FEEDBACK'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does nothing when the context is unmounted', (tester) async {
      final service = FeedbackService(workerUrl: 'http://test');
      final screenshotKey = GlobalKey();
      late BuildContext storedContext;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              storedContext = context;
              return const Text('placeholder');
            },
          ),
        ),
      ));

      // Dispose the widget tree so storedContext is no longer mounted.
      await tester.pumpWidget(const SizedBox());

      await launchFeedback(
        context: storedContext,
        service: service,
        screenshotKey: screenshotKey,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('SEND FEEDBACK'), findsNothing);
    });
  });
}
