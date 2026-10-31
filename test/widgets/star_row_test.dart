import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cosmic_match/game/theme/cosmic_theme.dart';
import 'package:cosmic_match/widgets/star_row.dart';

void main() {
  testWidgets('fills stars where the predicate is true and dims the rest', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StarRow(filled: (i) => i < 2, size: 14),
    ));

    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons.length, 3);
    expect(icons[0].color, kCosmicAccent);
    expect(icons[1].color, kCosmicAccent);
    expect(icons[2].color, kCosmicAccent.withValues(alpha: 0.3));
  });

  testWidgets('total: 5 yields five icons', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StarRow(total: 5, filled: (i) => i < 2, size: 14),
    ));

    expect(tester.widgetList<Icon>(find.byType(Icon)).length, 5);
  });
}
