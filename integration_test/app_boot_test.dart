import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive/hive.dart';
import 'package:cosmic_match/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_boot_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('app cold-starts and home screen PLAY button is visible within 5 s', (tester) async {
    await app.main();
    await tester.pump(const Duration(seconds: 5));

    // If we reach here without an exception, the app started successfully.
    // Verify the widget tree is non-empty (not just a blank error screen).
    expect(find.byType(app.CosmicMatchApp), findsOneWidget);
    // Stronger: verify the navigable home screen content is present.
    expect(find.textContaining('PLAY'), findsOneWidget,
        reason: 'Home screen must render with PLAY button after cold start');
  });
}
