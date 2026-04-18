import 'package:flutter/material.dart';
import '../../models/tile_type.dart';

// Derived from TileType.colorValue — single source of truth for tile colors.
// Adding a new TileType only requires updating tile_type.dart; this map updates automatically.
final Map<TileType, Color> kTilePalette = {
  for (final t in TileType.values) t: Color(t.colorValue)
};

// Derived from TileType.glowValue — used for selection border and hinted state.
final Map<TileType, Color> kTileGlowPalette = {
  for (final t in TileType.values) t: Color(t.glowValue)
};

// Selection now uses glow border — transparent fill (border drawn by _GlowBorder).
const Color kTileSelectedOverlay = Color(0x00000000);
