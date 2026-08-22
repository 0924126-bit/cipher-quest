import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide color definitions.
///
/// Decoder page: calm "old workshop" palette (Identity V cipher machine mood).
/// Dashboard: clean white Japanese business UI — white surfaces, hairline
/// borders, indigo (藍色) as the single accent color, plenty of whitespace.
/// Looks like a hand-built Japanese SaaS admin, not an AI template.
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

  // ---- Dashboard (white Japanese business UI) ----
  /// Page background / card surface / raised input surface.
  static const dashBg = Color(0xFFF6F7F9);
  static const dashSurface = Colors.white;
  static const dashSurfaceHi = Color(0xFFF1F3F6);

  /// Text: near-black ink & secondary grey.
  static const dashInk = Color(0xFF23272E);
  static const dashGrey = Color(0xFF757D89);

  /// Hairline borders.
  static const dashLine = Color(0xFFE4E7EC);

  /// 藍色 indigo = the single accent color (kept name for compatibility).
  static const dashBlue = Color(0xFF31589F);
  static const dashGreen = Color(0xFF2E7D46);
  static const dashRed = Color(0xFFC5392C);
  static const dashAmber = Color(0xFFB7791F);

  /// Curse purple for the cursed-role accents.
  static const dashCurse = Color(0xFF7A3FB5);
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

  /// White Japanese business UI for the dashboard.
  static ThemeData dashboard() {
    final base = ThemeData.light(useMaterial3: true);
    final text = GoogleFonts.notoSansJpTextTheme(base.textTheme);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.dashBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.dashBlue,
        secondary: AppColors.dashCurse,
        surface: AppColors.dashSurface,
        error: AppColors.dashRed,
        onPrimary: Colors.white,
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
        shape: Border(
          bottom: BorderSide(color: AppColors.dashLine),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.dashLine),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dashLine,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dashBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.dashInk,
          side: const BorderSide(color: AppColors.dashLine),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.dashBlue,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.dashSurfaceHi,
        hintStyle: const TextStyle(color: AppColors.dashGrey),
        labelStyle: const TextStyle(color: AppColors.dashGrey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.dashLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.dashLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.dashBlue, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.dashLine),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.dashInk,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.dashBlue
                : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.dashBlue.withValues(alpha: 0.35)
                : AppColors.dashLine),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.dashBlue,
        inactiveTrackColor: AppColors.dashLine,
        thumbColor: AppColors.dashBlue,
        overlayColor: AppColors.dashBlue.withValues(alpha: 0.12),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.dashBlue,
        unselectedLabelColor: AppColors.dashGrey,
        indicatorColor: AppColors.dashBlue,
        dividerColor: AppColors.dashLine,
      ),
    );
  }
}
