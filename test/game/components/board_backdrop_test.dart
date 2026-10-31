import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/board_backdrop.dart';

void main() {
  test('CosmicBackground renders at a portrait size without throwing', () {
    for (final size in [Vector2(400, 800), Vector2(1, 1)]) {
      final component = CosmicBackground()..size = size;
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => component.render(canvas), returnsNormally, reason: 'size=$size');
      recorder.endRecording();
    }
  });

  test('BoardBackdrop renders without throwing', () {
    for (final size in [Vector2(300, 300), Vector2(1, 1)]) {
      for (final tileSize in [0.0, 35.0]) {
        final component = BoardBackdrop(cols: 8, rows: 8)
          ..size = size
          ..tileSize = tileSize;
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        expect(() => component.render(canvas), returnsNormally,
            reason: 'size=$size tileSize=$tileSize');
        recorder.endRecording();
      }
    }
  });
}
