import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart' show Canvas, Color, Colors, CustomPainter, Paint, PaintingStyle, RRect, Radius, Rect, visibleForTesting;
import '../../models/tile_type.dart';
import '../match3_game.dart';
import '../theme/tile_palette.dart';
import '../world/grid_world.dart';
import 'tile_shape_painter.dart';

class GridTile extends RectangleComponent
    with TapCallbacks, DragCallbacks, RiverpodComponentMixin {
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
  Vector2? _basePosition;
  Vector2 _dragAccumulator = Vector2.zero();
  GridTile? _previewNeighbor;
  Vector2? _neighborBasePosition;
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

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final game = findGame() as Match3Game?;
    if (game == null || game.phase != GamePhase.idle) return;
    _basePosition = position.clone();
    _dragAccumulator = Vector2.zero();
    _previewNeighbor = null;
    _neighborBasePosition = null;
    priority = 100;
    event.handled = true;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_basePosition == null) return;
    _dragAccumulator += event.localDelta;
    final clampedDelta = _dragAccumulator.clone()..clampLength(0, size.x * 0.4);
    position = _basePosition! + clampedDelta;

    final dx = _dragAccumulator.x.abs();
    final dy = _dragAccumulator.y.abs();
    final threshold = size.x * 0.3;

    if (dx >= threshold || dy >= threshold) {
      if (_previewNeighbor == null) {
        final game = findGame() as Match3Game?;
        if (game != null) {
          final neighbor = resolveSwipeNeighbor(_dragAccumulator, game.world);
          if (neighbor != null) {
            _previewNeighbor = neighbor;
            _neighborBasePosition = neighbor.position.clone();
          }
        }
      }
      if (_previewNeighbor != null) {
        final neighborOffset = clampedDelta.clone()..negate();
        _previewNeighbor!.position = _neighborBasePosition! + neighborOffset;
      }
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final game = findGame() as Match3Game?;
    _snapBack();
    if (game == null) return;

    final dx = _dragAccumulator.x.abs();
    final dy = _dragAccumulator.y.abs();
    final threshold = size.x * 0.3;
    if (dx < threshold && dy < threshold) return;

    final neighbor = resolveSwipeNeighbor(_dragAccumulator, game.world);
    if (neighbor == null) return;

    game.world.runSwap(this, neighbor);
  }

  void _snapBack() {
    if (_basePosition != null) {
      position = _basePosition!;
      _basePosition = null;
    }
    if (_previewNeighbor != null && _neighborBasePosition != null) {
      _previewNeighbor!.position = _neighborBasePosition!;
      _previewNeighbor = null;
      _neighborBasePosition = null;
    }
    priority = 0;
  }

  @visibleForTesting
  GridTile? resolveSwipeNeighbor(Vector2 accumulator, GridWorld world) {
    final dx = accumulator.x.abs();
    final dy = accumulator.y.abs();
    int targetX = gridX;
    int targetY = gridY;
    if (dx >= dy) {
      targetX += accumulator.x > 0 ? 1 : -1;
    } else {
      targetY += accumulator.y > 0 ? 1 : -1;
    }
    if (targetX < 0 || targetX >= GridWorld.cols) return null;
    if (targetY < 0 || targetY >= GridWorld.rows) return null;
    return world.tiles[targetX][targetY];
  }
}
