import 'package:flutter/material.dart';
import '../../models/tile_type.dart';

// Derived from TileType.colorValue — single source of truth for tile colors.
// Adding a new TileType only requires updating tile_type.dart; this map updates automatically.
final Map<TileType, Color> kTilePalette = {
  for (final t in TileType.values) t: Color(t.colorValue)
};

// 0x66 ≈ 40% opacity white overlay — visible on all palette colours without
// obscuring the tile colour beneath.
const Color kTileSelectedOverlay = Color(0x66FFFFFF);
