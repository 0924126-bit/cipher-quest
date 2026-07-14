import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identity V inspired dark gothic palette + minimal dashboard theme.
class AppColors {
  // Decoder (gothic horror)
  static const bg = Color(0xFF0A0A0F);
  static const bgDeep = Color(0xFF050508);
  static const surface = Color(0xFF14141C);
  static const amber = Color(0xFFE8A33D); // lantern amber
  static const amberDim = Color(0xFF8A5F20);
  static const cyan = Color(0xFF52E0D8); // cipher glow
  static const cyanDim = Color(0xFF1E6B66);
  static const blood = Color(0xFFB3232A);
  static const bone = Color(0xFFD8D3C4); // aged paper text
  static const boneDim = Color(0xFF7A766A);
  static const violet = Color(0xFF7C5CBF);

  // Dashboard (minimal)
  static const dashBg = Color(0xFFFAFAFA);
  static const dashSurface = Colors.white;
  static const dashInk = Color(0xFF202124);
  static const dashGrey = Color(0xFF5F6368);
  static const dashLine = Color(0xFFE8EAED);
  static const dashBlue = Color(0xFF1A73E8);
  static const dashGreen = Color(0xFF188038);
  static const dashRed = Color(0xFFD93025);
  static const dashAmber = Color(0xFFF29900);
}

class AppTheme {
  /// Gothic theme for decoder pages.
  static ThemeData decoder() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.cyan,
        secondary: AppColors.amber,
        surface: AppColors.surface,
        error: AppColors.blood,
      ),
      textTheme: GoogleFonts.cinzelTextTheme(base.textTheme).copyWith(
        bodyMedium: GoogleFonts.shipporiMincho(
            color: AppColors.bone, fontSize: 14),
        bodySmall: GoogleFonts.shipporiMincho(
            color: AppColors.boneDim, fontSize: 12),
      ),
    );
  }

  /// Google-like minimal light theme for dashboard.
  static ThemeData dashboard() {
    final base = ThemeData.light(useMaterial3: true);
    final text = GoogleFonts.notoSansJpTextTheme(base.textTheme);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.dashBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.dashBlue,
        surface: AppColors.dashSurface,
        error: AppColors.dashRed,
      ),
      textTheme: text.apply(
        bodyColor: AppColors.dashInk,
        displayColor: AppColors.dashInk,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.dashInk,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.dashLine),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dashBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F3F4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dashBlue, width: 2),
        ),
      ),
    );
  }
}
