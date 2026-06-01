import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cosmic_match/screens/home_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'HomeScreen renders Clear feedback queue button and fires callback',
    (tester) async {
      var clearCalled = false;
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          onPlay: () {},
          onMap: () {},
          onFeedback: () {},
          onClearFeedbackQueue: () {
            clearCalled = true;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Clear feedback queue'), findsOneWidget);

      await tester.tap(find.text('Clear feedback queue'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Clear feedback queue?'), findsOneWidget);
      expect(find.text('This will permanently delete all unsent feedback.'), findsOneWidget);

      // Tap 'Clear' to confirm
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(clearCalled, isTrue);
    },
  );
}
