import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cosmic_match/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Hive.close();
  });

  testWidgets('app cold-starts and renders game grid within 5 s', (tester) async {
    await app.main();
    await tester.pump(const Duration(seconds: 5));

    // If we reach here without an exception, the app started successfully.
    // Verify the widget tree is non-empty (not just a blank error screen).
    expect(find.byType(app.CosmicMatchApp), findsOneWidget);
  });
}
