import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/tile_shape_painter.dart';
import 'package:cosmic_match/models/tile_type.dart';

void main() {
  group('tilePainterFor', () {
    test('returns a non-null painter for every TileType', () {
      for (final type in TileType.values) {
        expect(tilePainterFor(type, Colors.red), isNotNull,
            reason: 'tilePainterFor returned null for TileType.$type');
      }
    });

    test('returns correct painter subclass per TileType', () {
      expect(tilePainterFor(TileType.red, Colors.red), isA<MarsPainter>());
      expect(tilePainterFor(TileType.blue, Colors.blue), isA<NeptunePainter>());
      expect(tilePainterFor(TileType.yellow, Colors.yellow), isA<SolPainter>());
      expect(tilePainterFor(TileType.purple, Colors.purple), isA<NebulaPainter>());
      expect(tilePainterFor(TileType.white, Colors.white), isA<LunaPainter>());
      expect(tilePainterFor(TileType.orange, Colors.orange), isA<CometPainter>());
    });

    test('shouldRepaint always returns false for all painters (painters are immutable)', () {
      for (final type in TileType.values) {
        final p = tilePainterFor(type, Colors.red);
        expect(p.shouldRepaint(tilePainterFor(type, Colors.red)), isFalse,
            reason: 'TileType.$type painter shouldRepaint should always return false');
      }
    });

    test('paint completes for every TileType at normal and small sizes', () {
      for (final type in TileType.values) {
        for (final size in [const Size(48, 48), const Size(12, 12)]) {
          final painter = tilePainterFor(type, Colors.red);
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          expect(() => painter.paint(canvas, size), returnsNormally,
              reason: 'TileType.$type at $size');
          recorder.endRecording();
        }
      }
    });
  });
}
