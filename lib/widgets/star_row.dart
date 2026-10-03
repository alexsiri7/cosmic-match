import 'package:flutter/material.dart';
import '../game/theme/app_theme.dart';

class StarRow extends StatelessWidget {
  final int total;
  final bool Function(int index) filled;
  final double size;
  final EdgeInsetsGeometry starPadding;
  final MainAxisAlignment mainAxisAlignment;

  const StarRow({
    super.key,
    this.total = 3,
    required this.filled,
    required this.size,
    this.starPadding = const EdgeInsets.symmetric(horizontal: 4),
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: List.generate(total, (i) {
        final isFilled = filled(i);
        return Padding(
          padding: starPadding,
          child: Icon(
            Icons.star,
            size: size,
            color: isFilled ? kLyraAccent : kLyraAccent.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}
