import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import '../../models/tile_type.dart';
import '../match3_game.dart';
import '../theme/tile_palette.dart';

class GridTile extends PositionComponent
    with TapCallbacks, RiverpodComponentMixin {
  int gridX;
  int gridY;
  TileType tileType;

  late _GlowBorder _selectionBorder;

  GridTile({
    required this.gridX,
    required this.gridY,
    required this.tileType,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 && point.x <= size.x &&
      point.y >= 0 && point.y <= size.y;

  @override
  Future<void> onLoad() async {
    assert(kTilePalette.containsKey(tileType),
        'kTilePalette missing entry for TileType.$tileType — update tile_type.dart');
    assert(kTileGlowPalette.containsKey(tileType),
        'kTileGlowPalette missing entry for TileType.$tileType — update tile_type.dart');
    _selectionBorder = _GlowBorder(
      size: size.clone(),
      glowColor: kTileGlowPalette[tileType] ?? Colors.white,
    );
    _selectionBorder.visible = false;
    add(_selectionBorder);
  }

  @override
  void render(Canvas canvas) {
    // Cell background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0x1AFFFFFF),
    );
    // Tile shape
    _drawShape(canvas, size.x, size.y);
    super.render(canvas);
  }

  void _drawShape(Canvas canvas, double w, double h) {
    switch (tileType) {
      case TileType.red:    _drawMars(canvas, w, h);
      case TileType.blue:   _drawNeptune(canvas, w, h);
      case TileType.yellow: _drawSol(canvas, w, h);
      case TileType.purple: _drawNebula(canvas, w, h);
      case TileType.white:  _drawLuna(canvas, w, h);
      case TileType.orange: _drawComet(canvas, w, h);
    }
  }

  // Mars — filled circle with radial gradient + 2 crater dots
  void _drawMars(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final cy = h / 2;
    final r = w * 0.38;
    final color = kTilePalette[tileType]!;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()..shader = RadialGradient(
        colors: [color.withValues(alpha: 1.0), color.withValues(alpha: 0.7)],
      ).createShader(rect),
    );

    // Crater dots
    final craterPaint = Paint()..color = color.withValues(alpha: 0.4);
    canvas.drawCircle(Offset(cx - r * 0.3, cy - r * 0.2), r * 0.12, craterPaint);
    canvas.drawCircle(Offset(cx + r * 0.25, cy + r * 0.3), r * 0.09, craterPaint);
  }

  // Neptune — circle + ellipse ring
  void _drawNeptune(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final cy = h / 2;
    final r = w * 0.30;
    final color = kTilePalette[tileType]!;

    // Back ring arc
    final ringRect = Rect.fromCenter(
      center: Offset(cx, cy), width: r * 3.4, height: r * 0.84,
    );
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..color = color.withValues(alpha: 0.5);
    canvas.drawArc(ringRect, math.pi * 0.05, math.pi * 0.9, false, ringPaint);

    // Planet body
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()..shader = RadialGradient(
        colors: [color.withValues(alpha: 1.0), color.withValues(alpha: 0.75)],
        center: const Alignment(-0.3, -0.3),
      ).createShader(rect),
    );

    // Front ring arc
    canvas.drawArc(ringRect, math.pi * 1.05, math.pi * 0.9, false, ringPaint);
  }

  // Sol — 4-point star (8-vertex polygon) + center dot
  void _drawSol(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final cy = h / 2;
    final outerR = w * 0.42;
    final innerR = w * 0.13;
    final color = kTilePalette[tileType]!;

    final path = Path();
    for (int i = 0; i < 8; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (i * math.pi / 4) - math.pi / 2;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
    // White center dot
    canvas.drawCircle(Offset(cx, cy), w * 0.05, Paint()..color = Colors.white);
  }

  // Nebula — rounded rect + 2 cloud wisps
  void _drawNebula(Canvas canvas, double w, double h) {
    final color = kTilePalette[tileType]!;
    final x0 = w * 0.14;
    final rw = w * 0.72;
    final y0 = h * 0.22;
    final rh = h * 0.56;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x0, y0, rw, rh),
        Radius.circular(w * 0.20),
      ),
      Paint()..color = color,
    );

    // Cloud wisps
    final wispPaint = Paint()..color = color.withValues(alpha: 0.5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.35, y0 + rh * 0.15), width: rw * 0.5, height: rh * 0.3),
      wispPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.65, y0 + rh * 0.8), width: rw * 0.45, height: rh * 0.25),
      wispPaint,
    );
  }

  // Luna — crescent (circle with offset mask)
  void _drawLuna(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final cy = h / 2;
    final r = w * 0.36;
    final color = kTilePalette[tileType]!;

    final outer = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    final inner = Path()..addOval(Rect.fromCircle(
      center: Offset(cx + r * 0.45, cy - r * 0.15), radius: r * 0.92,
    ));
    final crescent = Path.combine(PathOperation.difference, outer, inner);

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawPath(
      crescent,
      Paint()..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.8)],
        center: const Alignment(-0.4, -0.4),
      ).createShader(rect),
    );
  }

  // Comet — circular head + two trail strokes
  void _drawComet(Canvas canvas, double w, double h) {
    final color = kTilePalette[tileType]!;
    final headCx = w * 0.6;
    final headCy = h * 0.45;
    final headR = w * 0.16;

    // Trail strokes
    final trailRect = Rect.fromLTWH(w * 0.08, h * 0.3, w * 0.55, h * 0.3);
    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = headR * 0.5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.0), color.withValues(alpha: 0.7)],
      ).createShader(trailRect);

    canvas.drawLine(Offset(w * 0.1, h * 0.4), Offset(headCx, headCy), trailPaint);

    final trailPaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = headR * 0.3
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.0), color.withValues(alpha: 0.5)],
      ).createShader(trailRect);
    canvas.drawLine(Offset(w * 0.15, h * 0.55), Offset(headCx, headCy + headR * 0.4), trailPaint2);

    // Head
    canvas.drawCircle(
      Offset(headCx, headCy), headR,
      Paint()..color = color,
    );
  }

  void select()   => _selectionBorder.visible = true;
  void deselect() => _selectionBorder.visible = false;

  @visibleForTesting
  bool get selectionBorderVisible => _selectionBorder.visible;

  @override
  void onTapDown(TapDownEvent event) {
    // INPUT GATE — drop all taps except when idle (SEC-008)
    final game = findGame() as Match3Game?;
    if (game == null || game.phase != GamePhase.idle) return;
    game.onTileTap(this);
    event.handled = true;
  }
}

// Selection border drawn in the tile's glow colour (solid stroke — no blur).
class _GlowBorder extends PositionComponent {
  final Color glowColor;
  bool visible = false;
  _GlowBorder({required Vector2 size, required this.glowColor})
      : super(size: size);

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = glowColor,
    );
  }
}
