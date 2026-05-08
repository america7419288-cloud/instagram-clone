import 'package:flutter/material.dart';

class ChatColors {
  // ── Backgrounds
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const darkSurface = Color(0xFF1C1C1E);
  static const darkCard = Color(0xFF2C2C2C);
  static const darkBorder = Color(0xFF3A3A3C);

  // ── Bubble Colors
  static const sentBlue = Color(0xFF3897F0);
  static const receivedLight = Color(0xFFEFEFEF);
  static const receivedDark = Color(0xFF2C2C2C);

  // ── Text
  static const primaryLight = Color(0xFF262626);
  static const primaryDark = Color(0xFFF5F5F5);
  static const secondary = Color(0xFF8E8E8E);
  static const white70 = Color(0xB3FFFFFF);

  // ── Brand
  static const blue = Color(0xFF0095F6);
  static const red = Color(0xFFFF3040);
  static const green = Color(0xFF44D662);

  // ── Separators
  static const separatorLight = Color(0xFFDBDBDB);
  static const separatorDark = Color(0xFF2C2C2C);

  // ── Gradient (story ring + send button)
  static const gradientColors = [
    Color(0xFFF58529),
    Color(0xFFDD2A7B),
    Color(0xFF8134AF),
    Color(0xFF515BD4),
  ];
}

class ChatDimens {
  // Bubble
  static const bubbleRadius = 20.0;
  static const bubbleTailRadius = 4.0;
  static const bubbleMaxWidth = 0.72; // % of screen
  static const bubblePadH = 14.0;
  static const bubblePadV = 10.0;

  // Spacing
  static const groupGap = 2.0;
  static const senderGap = 8.0;
  static const avatarSize = 28.0;

  // Input
  static const inputHeight = 36.0;
  static const inputRadius = 20.0;
  static const inputMaxHeight = 130.0;

  // Nav bar
  static const navBarHeight = 54.0;
}

class ChatTextStyles {
  static const fontFamily = 'SFPro';

  static TextStyle message({
    required Color color,
    double fontSize = 15,
  }) =>
      TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: fontFamily,
        height: 1.35,
        decoration: TextDecoration.none,
      );

  static TextStyle username({required Color color}) =>
      TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        fontFamily: fontFamily,
        decoration: TextDecoration.none,
      );

  static TextStyle caption({required Color color}) =>
      TextStyle(
        color: color,
        fontSize: 12,
        fontFamily: fontFamily,
        decoration: TextDecoration.none,
      );

  static TextStyle status({required Color color}) =>
      TextStyle(
        color: color,
        fontSize: 11,
        fontFamily: fontFamily,
        decoration: TextDecoration.none,
      );
}
