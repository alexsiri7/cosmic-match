import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart' show Canvas, Color, Colors, CustomPainter, Paint, PaintingStyle, RRect, Radius, Rect, visibleForTesting;
import '../../models/tile_type.dart';
import '../match3_game.dart';
import '../theme/tile_palette.dart';
import 'tile_shape_painter.dart';

class GridTile extends RectangleComponent
    with TapCallbacks, RiverpodComponentMixin {
  int gridX;
  int gridY;

  // Backing field for tileType — updating it refreshes the cached painter and glow.
  TileType _tileType;
  TileType get tileType => _tileType;
  set tileType(TileType value) {
    if (_tileType == value) return;
    _tileType = value;
    // Refresh cached painter and glow to reflect the new type.
    // Only runs after onLoad; before that the cache is set by onLoad itself.
    if (_painterReady) {
      _painter = tilePainterFor(_tileType, kTilePalette[_tileType]!);
      _glowPaint.color = kTileGlowPalette[_tileType] ?? Colors.white;
    }
  }

  bool _painterReady = false;
  bool _selected = false;
  late Paint _glowPaint;
  late CustomPainter _painter; // cached per-type — avoids per-frame allocation

  GridTile({
    required this.gridX,
    required this.gridY,
    required TileType tileType,
    required Vector2 position,
    required Vector2 size,
  })  : _tileType = tileType,
        super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    assert(kTilePalette.containsKey(_tileType),
        'kTilePalette missing entry for TileType.$_tileType — update tile_type.dart');

    // Cache painter once per type; the setter keeps this in sync if tileType is mutated.
    // Avoids the null-bang on kTilePalette[tileType]! inside render() and eliminates
    // 3,840 object allocations/second (64 tiles × 60fps).
    _painter = tilePainterFor(_tileType, kTilePalette[_tileType]!);

    _glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kTileGlowPalette[_tileType] ?? Colors.white;

    _painterReady = true;

    // Make the base rectangle transparent — tile body is drawn by the painter
    paint.color = const Color(0x00000000);
  }

  void select() => _selected = true;
  void deselect() => _selected = false;

  @visibleForTesting
  bool get selectionBorderVisible => _selected;

  @override
  void render(Canvas canvas) {
    _painter.paint(canvas, size.toSize()); // reuse cached instance — no allocation per frame
    if (_selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
          const Radius.circular(8),
        ),
        _glowPaint,
      );
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    // INPUT GATE — drop all taps except when idle
    final game = findGame() as Match3Game?;
    if (game == null || game.phase != GamePhase.idle) return;

    game.onTileTap(this);
    event.handled = true;
  }
}
