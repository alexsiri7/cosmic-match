import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../theme/cosmic_theme.dart';

// Draws the cosmic ink background + nebula gradient overlays.
class CosmicBackground extends PositionComponent {
  @override
  void render(Canvas canvas) {
    // 1. Solid ink fill
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = kCosmicInk);

    // 2. Nebula A — violet radial at top
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.x / 2, size.y * 0.15),
          width: size.x * 1.2, height: size.y * 0.6),
      Paint()..shader = RadialGradient(
        colors: [kCosmicNebulaA.withValues(alpha: 0.4), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y * 0.4)),
    );

    // 3. Nebula B — cyan-blue at bottom-right
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.x * 0.85, size.y * 0.85),
          width: size.x * 0.9, height: size.y * 0.5),
      Paint()..shader = RadialGradient(
        colors: [kCosmicNebulaB.withValues(alpha: 0.33), Colors.transparent],
      ).createShader(Rect.fromLTWH(size.x * 0.4, size.y * 0.55,
          size.x * 0.6, size.y * 0.45)),
    );
  }
}

// Dark rounded-rect panel behind the tile grid.
class BoardBackdrop extends PositionComponent {
  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(14),
      ),
      Paint()..color = kBoardBackdrop,
    );
  }
}
