import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Sanity-checks that golden baseline PNGs are not byte-for-byte identical.
/// If all baselines share the same pixel data the golden tests cannot distinguish
/// between distinct game states and will not catch visual regressions.
void main() {
  test('golden baselines are distinct from each other', () {
    final files = [
      'test/golden/goldens/fresh_board.png',
      'test/golden/goldens/post_match_clear.png',
      'test/golden/goldens/post_refill.png',
      'test/golden/goldens/score_bar.png',
    ];
    final bytes = files.map((p) => File(p).readAsBytesSync()).toList();
    for (int i = 0; i < bytes.length; i++) {
      for (int j = i + 1; j < bytes.length; j++) {
        expect(
          bytes[i],
          isNot(equals(bytes[j])),
          reason: '${files[i]} and ${files[j]} must not be identical — '
              'run "flutter test --update-goldens test/golden/" on Ubuntu '
              'with Flutter 3.41.7 to regenerate distinct baselines',
        );
      }
    }
  });
}
