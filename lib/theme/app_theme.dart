import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide color definitions.
///
/// Decoder page: calm "old workshop" palette (Identity V cipher machine mood).
/// Dashboard: Google-style minimal light palette (unchanged).
class AppColors {
  // ---- Decoder (quiet workshop) ----
  /// Page background top / bottom.
  static const bg = Color(0xFF171512);
  static const bgDeep = Color(0xFF0E0D0B);

  /// Panel-ish surface.
  static const surface = Color(0xFF201D19);

  /// Warm lantern amber, used sparingly for progress and lamps.
  static const amber = Color(0xFFD9A441);
  static const amberDim = Color(0xFF6E5526);

  /// Aged paper text.
  static const bone = Color(0xFFD8D3C4);
  static const boneDim = Color(0xFF837E70);

  /// Danger red (errors, delete).
  static const blood = Color(0xFFA8332F);

  /// Success green lamp on completion.
  static const lamp = Color(0xFF7FB069);

  // ---- Dashboard (minimal) ----
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
  /// Quiet workshop theme for decoder pages.
  static ThemeData decoder() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.amber,
        secondary: AppColors.bone,
        surface: AppColors.surface,
        error: AppColors.blood,
      ),
      textTheme: GoogleFonts.shipporiMinchoTextTheme(base.textTheme).apply(
        bodyColor: AppColors.bone,
        displayColor: AppColors.bone,
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
