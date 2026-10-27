import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:cosmic_match/core/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the screenshot fallback PNG decodes as a 1 by 1 image', () async {
    final codec = await ui.instantiateImageCodec(kTransparentPng);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1);
    expect(frame.image.height, 1);
  });
}
