import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kCardFill = Color(0x0FFFFFFF); // 6% white fill
const _kCardBorder = Color(0x1AFFFFFF); // 10% white border

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;

  const StatCard({
    required this.label,
    required this.value,
    required this.accentColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kCardFill,
        border: Border.all(color: _kCardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 9,
              letterSpacing: 1.5,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
