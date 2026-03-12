import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Masterpiece Palette: Deep Space & Electric Tones
  static const Color black = Color(0xFF000000);
  static const Color cardBg = Color(0xFF0A0A0B);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color electricViolet = Color(0xFF8B5CF6);
  static const Color toxicGreen = Color(0xFF22C55E);
  static const Color bloodRed = Color(0xFFEF4444);
  static const Color slate = Color(0xFF1E293B);
  static const Color glass = Color(0x1AFFFFFF);

  static ThemeData get masterTheme {
    final darkTheme = ThemeData.dark();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      colorScheme: ColorScheme.fromSeed(
        seedColor: electricViolet,
        brightness: Brightness.dark,
        background: black,
        surface: cardBg,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(darkTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w900,
          fontSize: 42,
          letterSpacing: -2.5,
          color: pureWhite,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: pureWhite.withOpacity(0.4),
          letterSpacing: 3,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  // Mappings for reliability
  static const primaryColor = electricViolet;
  static const keepColor = toxicGreen;
  static const trashColor = bloodRed;
  static const darkBg = black;
  static ThemeData get premiumTheme => masterTheme;
  static ThemeData get luxuryTheme => masterTheme;
  static ThemeData get lightTheme => masterTheme;
}
