import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cosmic_match/game/theme/tile_palette.dart';
import 'package:cosmic_match/models/tile_type.dart';

void main() {
  group('kTilePalette', () {
    test('contains an entry for every TileType value', () {
      for (final type in TileType.values) {
        expect(kTilePalette.containsKey(type), isTrue,
            reason: 'kTilePalette is missing entry for TileType.$type');
      }
    });

    test('palette color matches TileType.colorValue for every tile type', () {
      for (final type in TileType.values) {
        final expected = Color(type.colorValue);
        expect(kTilePalette[type], expected,
            reason:
                'kTilePalette[$type] diverges from TileType.colorValue — update tile_type.dart only');
      }
    });

    test('has exactly as many entries as TileType.values', () {
      expect(kTilePalette.length, TileType.values.length);
    });
  });

  group('kTileSelectedOverlay', () {
    test('has approximately 40% opacity (0x66 alpha)', () {
      // toARGB32() returns a 32-bit ARGB int: bits 24-31 = alpha
      final alpha = (kTileSelectedOverlay.toARGB32() >> 24) & 0xFF;
      expect(alpha, 0x66);
    });

    test('is white (RGB components are 0xFF)', () {
      final argb = kTileSelectedOverlay.toARGB32();
      final r = (argb >> 16) & 0xFF;
      final g = (argb >> 8) & 0xFF;
      final b = argb & 0xFF;
      expect(r, 0xFF);
      expect(g, 0xFF);
      expect(b, 0xFF);
    });
  });
}
