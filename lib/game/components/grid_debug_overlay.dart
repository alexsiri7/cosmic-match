import 'dart:ui';
import 'package:flame/components.dart';

/// Draws a thin outline around every grid cell so that tile misalignments
/// are immediately visible during QA.
///
/// Only added to the world when [assert] is enabled (debug builds).
class GridDebugOverlay extends Component {
  final int cols;
  final int rows;
  final double tileSize;
  final Vector2 boardOffset;

  GridDebugOverlay({
    required this.cols,
    required this.rows,
    required this.tileSize,
    required this.boardOffset,
  });

  late final _paint = Paint()
    ..color = const Color(0x66FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  @override
  void render(Canvas canvas) {
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        canvas.drawRect(
          Rect.fromLTWH(
            boardOffset.x + x * tileSize,
            boardOffset.y + y * tileSize,
            tileSize,
            tileSize,
          ),
          _paint,
        );
      }
    }
  }
}
