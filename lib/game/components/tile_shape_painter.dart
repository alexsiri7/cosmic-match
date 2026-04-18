import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/tile_type.dart';

// All tile painters below are immutable — they capture [color] at construction
// time and never change it, so shouldRepaint always returns false. If a painter
// ever gains mutable state (e.g. animation progress), update shouldRepaint accordingly.
/// Returns the appropriate tile painter for [type].
CustomPainter tilePainterFor(TileType type, Color color) => switch (type) {
  TileType.red    => MarsPainter(color),
  TileType.blue   => NeptunePainter(color),
  TileType.yellow => SolPainter(color),
  TileType.purple => NebulaPainter(color),
  TileType.white  => LunaPainter(color),
  TileType.orange => CometPainter(color),
};

/// Mars — filled circle with radial gradient + 2 crater dots.
class MarsPainter extends CustomPainter {
  final Color color;
  MarsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.38;
    final center = Offset(size.width / 2, size.height / 2);

    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 0.7,
      colors: [Colors.white.withValues(alpha: 0.4), color, color],
      stops: const [0.0, 0.4, 1.0],
    );
    final bodyPaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bodyPaint);

    final craterPaint = Paint()..color = Colors.black.withValues(alpha: 0.18);
    canvas.drawCircle(center + Offset(r * 0.3, r * 0.2), r * 0.12, craterPaint);
    canvas.drawCircle(center + Offset(-r * 0.25, -r * 0.1), r * 0.08,
        Paint()..color = Colors.black.withValues(alpha: 0.15));
  }

  @override
  bool shouldRepaint(covariant MarsPainter old) => false;
}

/// Neptune — planet body + elliptical ring.
class NeptunePainter extends CustomPainter {
  final Color color;
  NeptunePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = s * 0.30;
    final center = Offset(s / 2, s / 2);

    // Back of ring
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 3.4, height: r * 0.84),
      ringPaint,
    );

    // Planet body
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 0.8,
      colors: [Colors.white.withValues(alpha: 0.5), color, color],
      stops: const [0.0, 0.5, 1.0],
    );
    final bodyPaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bodyPaint);

    // Front of ring (bottom half arc)
    final frontRingPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round;
    final ovalRect = Rect.fromCenter(center: center, width: r * 3.4, height: r * 0.84);
    canvas.drawArc(ovalRect, 0, pi, false, frontRingPaint);
  }

  @override
  bool shouldRepaint(covariant NeptunePainter old) => false;
}

/// Sol — 4-point star polygon with center glow.
class SolPainter extends CustomPainter {
  final Color color;
  SolPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2, cy = s / 2;
    final bigR = s * 0.42;
    final smallR = s * 0.13;

    final path = Path();
    for (int i = 0; i < 8; i++) {
      final rad = i * pi / 4 - pi / 2;
      final d = i.isEven ? bigR : smallR;
      final x = cx + cos(rad) * d;
      final y = cy + sin(rad) * d;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final gradient = RadialGradient(
      colors: [Colors.white.withValues(alpha: 0.9), color, color.withValues(alpha: 0.95)],
      stops: const [0.0, 0.6, 1.0],
    );
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: Offset(cx, cy), radius: bigR));
    canvas.drawPath(path, paint);

    // Center glow dot
    canvas.drawCircle(Offset(cx, cy), s * 0.07,
        Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(covariant SolPainter old) => false;
}

/// Nebula — rounded lozenge with cloud wisps.
class NebulaPainter extends CustomPainter {
  final Color color;
  NebulaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.14, s * 0.14, s * 0.72, s * 0.72),
      Radius.circular(s * 0.20),
    );

    final gradient = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.35),
        color.withValues(alpha: 0.95),
        color.withValues(alpha: 0.7),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect.outerRect);
    canvas.drawRRect(rect, paint);

    // Cloud wisps
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.35, s * 0.38), width: s * 0.20, height: s * 0.10),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.62, s * 0.60), width: s * 0.26, height: s * 0.12),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant NebulaPainter old) => false;
}

/// Luna — crescent via circle-minus-circle mask.
class LunaPainter extends CustomPainter {
  final Color color;
  LunaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2, cy = s / 2;
    final r = s * 0.38;

    // Build crescent path by subtracting an offset circle
    final moonPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    final cutout = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(cx + r * 0.45, cy - r * 0.12),
        radius: r * 0.92,
      ));
    final crescent = Path.combine(PathOperation.difference, moonPath, cutout);

    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      colors: [Colors.white, color],
    );
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawPath(crescent, paint);
  }

  @override
  bool shouldRepaint(covariant LunaPainter old) => false;
}

/// Comet — circular head with radial gradient + dual quadratic bezier tails.
class CometPainter extends CustomPainter {
  final Color color;
  CometPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2, cy = s / 2;

    // Tail
    final tailPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.12
      ..strokeCap = StrokeCap.round;
    final tail = Path()
      ..moveTo(s * 0.15, s * 0.15)
      ..quadraticBezierTo(s * 0.35, s * 0.4, cx, cy);
    canvas.drawPath(tail, tailPaint);

    // Secondary tail
    final tail2Paint = Paint()
      ..color = color.withValues(alpha: 0.56)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.08
      ..strokeCap = StrokeCap.round;
    final tail2 = Path()
      ..moveTo(s * 0.10, s * 0.30)
      ..quadraticBezierTo(s * 0.32, s * 0.45, cx - 3, cy + 2);
    canvas.drawPath(tail2, tail2Paint);

    // Head
    final headCenter = Offset(cx + s * 0.08, cy + s * 0.08);
    final headGradient = RadialGradient(
      center: const Alignment(-0.2, -0.3),
      colors: [Colors.white.withValues(alpha: 0.95), color],
    );
    final headPaint = Paint()
      ..shader = headGradient.createShader(
        Rect.fromCircle(center: headCenter, radius: s * 0.22),
      );
    canvas.drawCircle(headCenter, s * 0.22, headPaint);
  }

  @override
  bool shouldRepaint(covariant CometPainter old) => false;
}
