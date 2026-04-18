import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Lyra galaxy color constants (M1 — only galaxy implemented)
const Color kLyraInk = Color(0xFF0D0A1A);
const Color kLyraNebulaA = Color(0xFF4A1F85); // violet
const Color kLyraNebulaB = Color(0xFF1A4880); // cobalt blue
const Color kLyraAccent = Color(0xFFC070E8);
const Color kLyraStroke = Color(0xFF6A55A8);
const Color kLyraWarning = Color(0xFFF08A3E); // orange alert tone

final ThemeData _cosmicTheme = _buildCosmicTheme();

ThemeData _buildCosmicTheme() {
  final dark = ThemeData.dark();
  return dark.copyWith(
    scaffoldBackgroundColor: kLyraInk,
    colorScheme: dark.colorScheme.copyWith(
      surface: kLyraInk,
      primary: kLyraAccent,
    ),
    textTheme: GoogleFonts.ibmPlexMonoTextTheme(dark.textTheme),
  );
}

ThemeData cosmicTheme() => _cosmicTheme;
