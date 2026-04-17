import 'dart:ui';
import 'package:flame/components.dart';

/// Draws a thin outline around every grid cell so that tile misalignments
/// are immediately visible during QA.
///
/// Intended for debug builds only — [GridWorld] wraps instantiation in an
/// `assert` block so this component is never added in release builds.
class GridDebugOverlay extends Component {
  final int cols;
  final int rows;
  // Callbacks instead of captured values so the overlay reflects live layout
  // even after a screen resize (onGameResize reassigns boardOffset / tileSize).
  final Vector2 Function() getOffset;
  final double Function() getTileSize;

  GridDebugOverlay({
    required this.cols,
    required this.rows,
    required this.getOffset,
    required this.getTileSize,
  });

  late final _paint = Paint()
    ..color = const Color(0x66FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  @override
  void render(Canvas canvas) {
    final offset = getOffset();
    final size = getTileSize();
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        canvas.drawRect(
          Rect.fromLTWH(
            offset.x + x * size,
            offset.y + y * size,
            size,
            size,
          ),
          _paint,
        );
      }
    }
  }
}
