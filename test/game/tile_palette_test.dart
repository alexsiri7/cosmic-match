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
    test('is fully transparent (selection now uses glow border)', () {
      final alpha = (kTileSelectedOverlay.toARGB32() >> 24) & 0xFF;
      expect(alpha, 0x00);
    });
  });


  group('kTileGlowPalette', () {
    test('contains an entry for every TileType value', () {
      for (final type in TileType.values) {
        expect(kTileGlowPalette.containsKey(type), isTrue,
            reason: 'kTileGlowPalette is missing entry for TileType.$type');
      }
    });

    test('glow color matches TileType.glowValue for every tile type', () {
      for (final type in TileType.values) {
        final expected = Color(type.glowValue);
        expect(kTileGlowPalette[type], expected,
            reason:
                'kTileGlowPalette[$type] diverges from TileType.glowValue — update tile_type.dart only');
      }
    });
  });
}
