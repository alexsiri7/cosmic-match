// Tests for cosmicTheme() and the kLyra* color token constants in app_theme.dart.
// Verifies that the theme is correctly wired to the palette constants so that
// future token value changes don't silently break the MaterialApp theme.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cosmic_match/game/theme/app_theme.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Disable runtime font fetching; fonts are not bundled in tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('cosmicTheme color tokens', () {
    // Pump a widget that uses cosmicTheme() so the test exercises MaterialApp
    // theme resolution without triggering the top-level font initialisation
    // failure outside the widget-test runner.
    testWidgets('scaffoldBackgroundColor matches kLyraInk', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: cosmicTheme(),
          home: const SizedBox.shrink(),
        ),
      );
      final theme = Theme.of(tester.element(find.byType(SizedBox)));
      expect(theme.scaffoldBackgroundColor, kLyraInk);
    });

    testWidgets('colorScheme.primary matches kLyraAccent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: cosmicTheme(),
          home: const SizedBox.shrink(),
        ),
      );
      final theme = Theme.of(tester.element(find.byType(SizedBox)));
      expect(theme.colorScheme.primary, kLyraAccent);
    });

    testWidgets('colorScheme.surface matches kLyraInk', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: cosmicTheme(),
          home: const SizedBox.shrink(),
        ),
      );
      final theme = Theme.of(tester.element(find.byType(SizedBox)));
      expect(theme.colorScheme.surface, kLyraInk);
    });
  });
}
