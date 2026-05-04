import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart' show Canvas, Colors, CustomPainter, Paint, PaintingStyle, RRect, Radius, Rect, visibleForTesting;
import '../../core/logger.dart';
import '../../models/tile_type.dart';
import '../match3_game.dart';
import '../theme/tile_palette.dart';
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
      final color = kTilePalette[_tileType];
      if (color != null) {
        _painter = tilePainterFor(_tileType, color);
        _glowPaint.color = kTileGlowPalette[_tileType] ?? Colors.white;
      }
    }
  }

  bool _painterReady = false;
  bool _selected = false;

  // --- drag state (reset on each gesture) ---
  bool _dragging = false;
  Vector2 _dragOriginPosition = Vector2.zero();
  Vector2 _accumulatedDelta = Vector2.zero();
  GridTile? _dragPreviewNeighbor;
  Vector2 _dragNeighborOrigin = Vector2.zero();
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
    final color = kTilePalette[_tileType];
    assert(color != null,
        'kTilePalette missing entry for TileType.$_tileType — update tile_type.dart');

    _painter = tilePainterFor(_tileType, color ?? Colors.white);

    _glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kTileGlowPalette[_tileType] ?? Colors.white;

    _painterReady = true;

    // Make the base rectangle transparent — tile body is drawn by the painter
    paint.color = Colors.transparent;
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

  SwipeDirection? _dominantDirection(Vector2 delta, double threshold) {
    if (delta.length < threshold) return null;
    if (delta.x.abs() >= delta.y.abs()) {
      return delta.x > 0 ? SwipeDirection.right : SwipeDirection.left;
    } else {
      return delta.y > 0 ? SwipeDirection.down : SwipeDirection.up;
    }
  }

  /// Thin wrapper exposed for unit testing without a Flame engine.
  /// Consistent with the [selectionBorderVisible] pattern in this file.
  @visibleForTesting
  SwipeDirection? dominantDirectionForTest(Vector2 delta, double threshold) =>
      _dominantDirection(delta, threshold);

  /// Restores all drag-mutated positions and clears drag state.
  /// Called from every drag exit path to prevent tiles staying displaced.
  void _resetDragState() {
    _dragging = false;
    position = _dragOriginPosition;
    if (_dragPreviewNeighbor != null) {
      _dragPreviewNeighbor!.position = _dragNeighborOrigin;
      _dragPreviewNeighbor = null;
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final game = findGame() as Match3Game?;
    if (game == null || game.phase != GamePhase.idle) return;

    _dragging = true;
    _dragOriginPosition = position.clone();
    _accumulatedDelta = Vector2.zero();
    _dragPreviewNeighbor = null;
    event.handled = true;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_dragging) return;
    _accumulatedDelta += event.localDelta;

    final threshold = size.x * 0.3;
    final direction = _dominantDirection(_accumulatedDelta, threshold);
    if (direction == null) return; // below threshold — no preview yet

    // Constrain preview offset to dominant axis only
    final axisOffset = direction == SwipeDirection.left || direction == SwipeDirection.right
        ? Vector2(_accumulatedDelta.x.clamp(-size.x * 0.5, size.x * 0.5), 0)
        : Vector2(0, _accumulatedDelta.y.clamp(-size.y * 0.5, size.y * 0.5));

    position = _dragOriginPosition + axisOffset;

    // Preview neighbor tile (subtle counter-offset)
    final game = findGame() as Match3Game?;
    if (game == null) {
      _resetDragState();
      return;
    }
    final neighborX = gridX + direction.dx;
    final neighborY = gridY + direction.dy;
    final neighbor = game.world.tileAt(neighborX, neighborY);
    // Restore previous neighbor whenever the target changes, including to null/OOB.
    if (neighbor != _dragPreviewNeighbor) {
      if (_dragPreviewNeighbor != null) {
        _dragPreviewNeighbor!.position = _dragNeighborOrigin;
      }
      _dragPreviewNeighbor = neighbor;
      if (neighbor != null) {
        _dragNeighborOrigin = neighbor.position.clone();
      }
    }
    if (_dragPreviewNeighbor != null) {
      _dragPreviewNeighbor!.position = _dragNeighborOrigin - axisOffset * 0.3;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!_dragging) return;

    // Snap tiles back to home positions before handing off to runSwap
    // (runSwap records position at start, so must be canonical first)
    _resetDragState();

    final direction = _dominantDirection(_accumulatedDelta, size.x * 0.3);
    if (direction == null) return; // too short — ignore

    final game = findGame() as Match3Game?;
    if (game == null) {
      gameLogger.w('GridTile.onDragEnd: findGame() returned null — swap dropped');
      return;
    }
    game.onTileSwipe(this, direction);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (!_dragging) return;
    _resetDragState();
  }
}
