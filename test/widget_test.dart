import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/main.dart';

void main() {
  testWidgets('App renders home screen with title', (WidgetTester tester) async {
    await tester.pumpWidget(const CosmicMatchApp());

    expect(find.text('Cosmic Match'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
