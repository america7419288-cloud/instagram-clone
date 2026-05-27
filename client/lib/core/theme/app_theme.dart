// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  AppColors._();

  // ─── PRIMARY COLORS ────────────────────────────────────
  static const Color primary = Color(0xFF0095F6); // igds_prism_blue_05
  static const Color secondary = Color(0xFFED4956); // fbpay_error_or_destructive
  static const Color error = Color(0xFFED4956);
  static const Color accent = Color(0xFF0095F6);

  // ─── UTILITY COLORS ────────────────────────────────────
  static const Color like = Color(0xFFFF3040); // bds_red_5
  static const Color verified = Color(0xFF0095F6); // badge_color
  static const Color link = Color(0xFF00376B); // bds_blue_8
  static const Color textLink = Color(0xFF0095F6);
  static const Color iosBlue = Color(0xFF0095F6);

  // ─── LIGHT MODE (Instagram Standard) ───────────────────
  static const Color background = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF000000); // igds_primary_text
  static const Color textSecondary = Color(0xFF737373); // bds_grey_6
  static const Color textTertiary = Color(0xFFC7C7C7); // bds_grey_3
  static const Color separator = Color(0xFFDBDBDB); // igds_separator
  static const Color divider = Color(0xFFDBDBDB);
  static const Color border = Color(0xFFDBDBDB);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFFAFAFA);
  static const Color shimmerBase = Color(0xFFEBEBEB);

  // ─── DARK MODE (Instagram Prism) ───────────────────────
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF121212); // design_dark_default_color_background
  static const Color darkTextPrimary = Color(0xFFF5F5F5); // bds_grey_0
  static const Color darkTextSecondary = Color(0xFFA8A8A8); // bds_grey_4
  static const Color darkTextTertiary = Color(0xFF363636); // bds_grey_8
  static const Color darkSeparator = Color(0xFF262626); // bds_grey_9
  static const Color darkDivider = Color(0xFF262626);
  static const Color darkCardBackground = Color(0xFF121212);
  static const Color darkInputBackground = Color(0xFF262626);
  static const Color darkShimmerBase = Color(0xFF262626);

  // ─── PRISM SPECIFIC ────────────────────────────────────
  static const Color prismBlack = Color(0xFF0C1014); // igds_prism_black
  static const Color prismGray10 = Color(0xFF212328); // igds_prism_gray_10
  static const Color prismBlue05 = Color(0xFF0095F6);

  // ─── GRADIENTS (Official Camera) ───────────────────────
  static const Color storyStart = Color(0xFFA307BA); // camera_gradient_start
  static const Color storyMid = Color(0xFFD73889); // camera_gradient_center
  static const Color storyEnd = Color(0xFFFD8D32); // camera_gradient_end

  static const LinearGradient instagramGradient = LinearGradient(
    colors: [
      Color(0xFFA307BA),
      Color(0xFFD73889),
      Color(0xFFFD8D32),
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const SweepGradient storyRingGradient = SweepGradient(
    colors: [
      Color(0xFFA307BA),
      Color(0xFFD73889),
      Color(0xFFFD8D32),
      Color(0xFFA307BA), // Wrap around
    ],
  );
}

class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'Instagram-Sans';

  // ─── LIGHT THEME ───────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: _fontFamily,

    // Remove Material Ripples for iOS feel
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,

    textTheme: _buildTextTheme(Colors.black),

    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    ),

    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 44,
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        decoration: TextDecoration.none,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.separator,
      thickness: 0.33,
      space: 0.33,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.background,
      elevation: 0,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        splashFactory: NoSplash.splashFactory,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: _fontFamily,
          decoration: TextDecoration.none,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        splashFactory: NoSplash.splashFactory,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          fontFamily: _fontFamily,
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );

  // ─── DARK THEME ────────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.darkBackground,
    fontFamily: _fontFamily,

    // Remove Material Ripples for iOS feel
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,

    textTheme: _buildTextTheme(Colors.white),

    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    ),

    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.darkBackground,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.error,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 44,
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary, size: 24),
      titleTextStyle: TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        decoration: TextDecoration.none,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.darkSeparator,
      thickness: 0.33,
      space: 0.33,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkBackground,
      elevation: 0,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
    ),
  );

  static TextTheme _buildTextTheme(Color color) {
    const style = TextStyle(
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      decorationThickness: 0,
      fontFamily: _fontFamily,
    );
    return TextTheme(
      displayLarge: style.copyWith(color: color),
      displayMedium: style.copyWith(color: color),
      displaySmall: style.copyWith(color: color),
      headlineLarge: style.copyWith(color: color),
      headlineMedium: style.copyWith(color: color),
      headlineSmall: style.copyWith(color: color),
      titleLarge: style.copyWith(color: color, fontWeight: FontWeight.w600),
      titleMedium: style.copyWith(color: color),
      titleSmall: style.copyWith(color: color),
      bodyLarge: style.copyWith(color: color),
      bodyMedium: style.copyWith(color: color),
      bodySmall: style.copyWith(color: color.withOpacity(0.6)),
      labelLarge: style.copyWith(color: color),
      labelMedium: style.copyWith(color: color),
      labelSmall: style.copyWith(color: color),
    );
  }
}

// ─── DURATION EXTENSIONS ─────────────────────────────────
extension NumDurationExtension on num {
  Duration get ms => Duration(milliseconds: round());
  Duration get seconds => Duration(seconds: round());
}
