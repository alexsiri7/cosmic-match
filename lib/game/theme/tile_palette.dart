import 'package:flutter/material.dart';
import '../../models/tile_type.dart';

const Map<TileType, Color> kTilePalette = {
  TileType.red: Color(0xFFE53935),
  TileType.blue: Color(0xFF1E88E5),
  TileType.yellow: Color(0xFFFDD835),
  TileType.purple: Color(0xFF8E24AA),
  TileType.white: Color(0xFFEEEEEE),
  TileType.orange: Color(0xFFFB8C00),
};

const Color kTileSelectedOverlay = Color(0x66FFFFFF);
