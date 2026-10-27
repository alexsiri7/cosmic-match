import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cosmic_match/widgets/frosted_card.dart';

void main() {
  testWidgets('renders its child with the requested radius', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: FrostedCard(borderRadius: 24, child: Text('hi')),
      ),
    ));

    expect(find.text('hi'), findsOneWidget);

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(24));
  });
}
