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

  testWidgets(
    'Cancel in the clear dialog does not fire onClearFeedbackQueue',
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

      await tester.tap(find.text('Clear feedback queue'));
      await tester.pumpAndSettle();

      expect(find.text('Clear feedback queue?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(clearCalled, isFalse);
      expect(find.text('Clear feedback queue?'), findsNothing);
    },
  );

  testWidgets('Play button fires onPlay', (tester) async {
    var playCalled = false;
    var mapCalled = false;

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        onPlay: () => playCalled = true,
        onMap: () => mapCalled = true,
        onFeedback: () {},
        onClearFeedbackQueue: () {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('PLAY LEVEL'));
    await tester.pump();

    expect(playCalled, isTrue);
    expect(mapCalled, isFalse);
  });

  testWidgets('Galaxy Map button fires onMap', (tester) async {
    var playCalled = false;
    var mapCalled = false;

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        onPlay: () => playCalled = true,
        onMap: () => mapCalled = true,
        onFeedback: () {},
        onClearFeedbackQueue: () {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Galaxy Map'));
    await tester.pump();

    expect(mapCalled, isTrue);
    expect(playCalled, isFalse);
  });

  testWidgets('HomeScreen starfield is deterministic across fresh builds',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<List<(double?, double?, double?, Color?)>> pumpStars() async {
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          onPlay: () {},
          onMap: () {},
          onFeedback: () {},
          onClearFeedbackQueue: () {},
        ),
      ));
      await tester.pumpAndSettle();
      return [
        for (final p in tester.widgetList<Positioned>(find.byType(Positioned)))
          if (p.child case Container(
            decoration: BoxDecoration(shape: BoxShape.circle, :final color),
            :final constraints,
          ))
            (p.left, p.top, constraints?.maxWidth, color),
      ];
    }

    final first = await pumpStars();
    await tester.pumpWidget(const SizedBox());
    final second = await pumpStars();

    expect(first, hasLength(80));
    expect(second, first);
    expect(first.map((s) => (s.$1, s.$2)).toSet().length, greaterThan(1));
  });
}
