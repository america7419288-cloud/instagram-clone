// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  AppColors._();

  // ─── PRIMARY COLORS ────────────────────────────────────
  static const Color primary = Color(0xFF0095F6);
  static const Color secondary = Color(0xFFED4956);
  static const Color error = Color(0xFFED4956);
  static const Color accent = Color(0xFF0095F6);

  // ─── UTILITY COLORS ────────────────────────────────────
  static const Color like = Color(0xFFFF3040);
  static const Color verified = Color(0xFF0095F6);
  static const Color link = Color(0xFF00376B);
  static const Color textLink = Color(0xFF0095F6);
  static const Color iosBlue = Color(0xFF0095F6);

  // ─── LIGHT MODE (iOS Pure White) ────────────────────────
  static const Color background = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF262626);
  static const Color textSecondary = Color(0xFF8E8E8E);
  static const Color textTertiary = Color(0xFFC7C7CC);
  static const Color separator = Color(0xFFDBDBDB);
  static const Color divider = Color(0xFFDBDBDB);
  static const Color border = Color(0xFFDBDBDB);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFFAFAFA);
  static const Color shimmerBase = Color(0xFFEBEBEB);

  // ─── DARK MODE (iOS True Black) ─────────────────────────
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E8E);
  static const Color darkTextTertiary = Color(0xFF3A3A3C);
  static const Color darkSeparator = Color(0xFF2C2C2C);
  static const Color darkDivider = Color(0xFF2C2C2C);
  static const Color darkCardBackground = Color(0xFF121212);
  static const Color darkInputBackground = Color(0xFF262626);
  static const Color darkShimmerBase = Color(0xFF262626);

  // ─── GRADIENTS ─────────────────────────────────────────
  static const Color storyStart = Color(0xFFF58529);
  static const Color storyMid = Color(0xFFDD2A7B);
  static const Color storyEnd = Color(0xFF8134AF);

  static const LinearGradient instagramGradient = LinearGradient(
    colors: [
      Color(0xFFF58529),
      Color(0xFFDD2A7B),
      Color(0xFF8134AF),
      Color(0xFF515BD4),
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const SweepGradient storyRingGradient = SweepGradient(
    colors: [
      Color(0xFFF58529),
      Color(0xFFDD2A7B),
      Color(0xFF8134AF),
      Color(0xFF515BD4),
      Color(0xFFF58529), // Wrap around
    ],
  );
}

class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'SF-Pro';

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
}
