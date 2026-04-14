import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../models/tile_type.dart';

/// Visual representation of a single tile on the board.
class TileComponent extends PositionComponent with TapCallbacks {
  TileType tileType;
  BonusTileType? bonusType;
  int row;
  int col;
  bool isSelected = false;

  /// Accumulated time for animated effects.
  double _elapsed = 0;

  /// Callback invoked when this tile is tapped.
  void Function(TileComponent)? onTileTapped;

  TileComponent({
    required this.tileType,
    required this.row,
    required this.col,
    required super.size,
    required super.position,
    this.bonusType,
    this.onTileTapped,
  });

  static Color colorForType(TileType type) {
    switch (type) {
      case TileType.planetRed:
        return const Color(0xFFE53935);
      case TileType.planetBlue:
        return const Color(0xFF1E88E5);
      case TileType.star:
        return const Color(0xFFFFD600);
      case TileType.nebula:
        return const Color(0xFFAB47BC);
      case TileType.moon:
        return const Color(0xFFBDBDBD);
      case TileType.comet:
        return const Color(0xFF00E5FF);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    onTileTapped?.call(this);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = colorForType(tileType);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final radius = size.x / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius * 0.4)),
      paint,
    );

    // Bonus tile visual indicators
    if (bonusType != null) {
      _renderBonusIndicator(canvas, rect, radius);
    }

    // Selection highlight: bright white border
    if (isSelected) {
      final highlightPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius * 0.4)),
        highlightPaint,
      );
    }
  }

  void _renderBonusIndicator(Canvas canvas, Rect rect, double radius) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;

    switch (bonusType!) {
      case BonusTileType.pulsar:
        // Pulsing glow — animated ring that expands and contracts
        final pulse = 0.8 + 0.2 * math.sin(_elapsed * 4);
        final glowPaint = Paint()
          ..color = const Color(0xAAFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(
          Offset(cx, cy),
          radius * 0.5 * pulse,
          glowPaint,
        );
      case BonusTileType.blackHole:
        // Dark swirl — concentric dark rings
        final swirlPaint = Paint()
          ..color = const Color(0xCC000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(Offset(cx, cy), radius * 0.35, swirlPaint);
        final outerPaint = Paint()
          ..color = const Color(0x88440088)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        final rotation = _elapsed * 2;
        canvas.drawCircle(
          Offset(cx + math.cos(rotation) * 2, cy + math.sin(rotation) * 2),
          radius * 0.5,
          outerPaint,
        );
      case BonusTileType.supernova:
        // Bright burst — radiating lines from centre
        final burstPaint = Paint()
          ..color = const Color(0xDDFFFF00)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        const rays = 8;
        final rayLen = radius * 0.45;
        for (int i = 0; i < rays; i++) {
          final angle = (i * math.pi * 2 / rays) + _elapsed * 1.5;
          canvas.drawLine(
            Offset(cx, cy),
            Offset(cx + math.cos(angle) * rayLen,
                cy + math.sin(angle) * rayLen),
            burstPaint,
          );
        }
    }
  }
}
