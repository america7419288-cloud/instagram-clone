// lib/core/theme/ios_colors.dart
import 'package:flutter/material.dart';

class IosColors {
  // ── Light Mode ──
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSecondaryBg = Color(0xFFF2F2F7);
  static const lightTertiaryBg = Color(0xFFFFFFFF);
  static const lightGroupedBg = Color(0xFFF2F2F7);
  static const lightPrimary = Color(0xFF000000);
  static const lightSecondary = Color(0xFF8E8E93);
  static const lightTertiary = Color(0xFFC7C7CC);
  static const lightSeparator = Color(0xFFC6C6C8);
  static const lightFill = Color(0x3C787880);

  // ── Dark Mode ──
  static const darkBackground = Color(0xFF000000);
  static const darkSecondaryBg = Color(0xFF1C1C1E);
  static const darkTertiaryBg = Color(0xFF2C2C2E);
  static const darkGroupedBg = Color(0xFF1C1C1E);
  static const darkPrimary = Color(0xFFFFFFFF);
  static const darkSecondary = Color(0xFF8E8E93);
  static const darkTertiary = Color(0xFF48484A);
  static const darkSeparator = Color(0xFF38383A);
  static const darkFill = Color(0x5C787880);

  // ── Instagram Brand ──
  static const igBlue = Color(0xFF0095F6);
  static const igRed = Color(0xFFED4956);
  static const igGreen = Color(0xFF58C322);
  static const igGold = Color(0xFFFFD700);
  static const igGradientStart = Color(0xFFF58529);
  static const igGradientMid = Color(0xFFDD2A7B);
  static const igGradientEnd = Color(0xFF8134AF);

  // ── Adaptive ──
  static Color background(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark
      ? darkBackground : lightBackground;

  static Color secondaryBg(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark
      ? darkSecondaryBg : lightSecondaryBg;

  static Color primary(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark
      ? darkPrimary : lightPrimary;

  static Color secondary(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark
      ? darkSecondary : lightSecondary;

  static Color separator(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark
      ? darkSeparator : lightSeparator;

  static Color surface(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark
      ? darkSecondaryBg : lightBackground;

  static Color fill(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark
      ? darkFill : lightFill;
}
