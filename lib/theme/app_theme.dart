import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide color definitions.
///
/// Decoder page: calm "old workshop" palette (Identity V cipher machine mood).
/// Dashboard: dark cave × Identity V operator console. Warm lantern light
/// against deep cave rock, aged paper text, vermilion accents — designed to
/// feel like a hand-crafted Japanese festival control room, not a template.
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

  // ---- Dashboard (cave operator console) ----
  /// Deep cave background / slightly lit panel rock.
  static const dashBg = Color(0xFF121110);
  static const dashSurface = Color(0xFF1C1A17);
  static const dashSurfaceHi = Color(0xFF262320);

  /// Aged paper ink & secondary text.
  static const dashInk = Color(0xFFE4DFD1);
  static const dashGrey = Color(0xFF8D877A);

  /// Hairline borders like old brass fittings.
  static const dashLine = Color(0xFF37332C);

  /// Lantern amber = primary action color.
  static const dashBlue = Color(0xFFD9A441); // primary (kept name for compat)
  static const dashGreen = Color(0xFF7FB069);
  static const dashRed = Color(0xFFC94F43);
  static const dashAmber = Color(0xFFD9A441);

  /// Curse purple for the cursed-role accents.
  static const dashCurse = Color(0xFF9B59D0);
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

  /// Cave operator console theme for the dashboard.
  static ThemeData dashboard() {
    final base = ThemeData.dark(useMaterial3: true);
    final text = GoogleFonts.notoSansJpTextTheme(base.textTheme);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.dashBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.dashAmber,
        secondary: AppColors.dashCurse,
        surface: AppColors.dashSurface,
        error: AppColors.dashRed,
        onPrimary: const Color(0xFF1C1408),
      ),
      textTheme: text.apply(
        bodyColor: AppColors.dashInk,
        displayColor: AppColors.dashInk,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.dashBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.dashInk,
      ),
      cardTheme: CardThemeData(
        color: AppColors.dashSurface,
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
          backgroundColor: AppColors.dashAmber,
          foregroundColor: const Color(0xFF1C1408),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.dashAmber,
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
          borderSide: const BorderSide(color: AppColors.dashAmber, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.dashSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.dashLine),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.dashSurfaceHi,
        contentTextStyle: TextStyle(color: AppColors.dashInk),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.dashAmber
                : AppColors.dashGrey),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.dashAmber.withValues(alpha: 0.4)
                : AppColors.dashLine),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.dashAmber,
        inactiveTrackColor: AppColors.dashLine,
        thumbColor: AppColors.dashAmber,
        overlayColor: AppColors.dashAmber.withValues(alpha: 0.15),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.dashAmber,
        unselectedLabelColor: AppColors.dashGrey,
        indicatorColor: AppColors.dashAmber,
        dividerColor: AppColors.dashLine,
      ),
    );
  }
}
