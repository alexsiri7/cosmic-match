import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cosmic_match/screens/map_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('MapScreen', () {
    testWidgets('renders placeholder text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MapScreen(onBack: () {})),
      );
      expect(find.text('GALAXY MAP — COMING SOON'), findsOneWidget);
    });

    testWidgets('back button invokes onBack callback', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        MaterialApp(home: MapScreen(onBack: () => callCount++)),
      );
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(callCount, 1);
    });
  });
}
