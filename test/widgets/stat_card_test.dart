import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cosmic_match/widgets/stat_card.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows label and value in the accent color', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StatCard(label: 'SCORE', value: '1,500', accentColor: Colors.amber),
      ),
    ));

    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('1,500'), findsOneWidget);
    expect(tester.widget<Text>(find.text('1,500')).style?.color, Colors.amber);
  });
}
