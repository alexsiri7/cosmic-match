import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../models/tile_type.dart';

/// Visual representation of a single tile on the board.
class TileComponent extends PositionComponent with TapCallbacks {
  TileType tileType;
  int row;
  int col;
  bool isSelected = false;

  /// Callback invoked when this tile is tapped.
  void Function(TileComponent)? onTileTapped;

  TileComponent({
    required this.tileType,
    required this.row,
    required this.col,
    required super.size,
    required super.position,
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
  void render(Canvas canvas) {
    final paint = Paint()..color = colorForType(tileType);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final radius = size.x / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius * 0.4)),
      paint,
    );

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
}
