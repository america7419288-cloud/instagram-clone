import 'package:flutter/cupertino.dart';

class ChatUIConstants {
  // Light Mode Colors
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color bubbleReceivedLight = Color(0xFFEFEFEF);
  static const Color bubbleSent = Color(0xFF3897F0);
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF8E8E8E);
  static const Color separatorLight = Color(0xFFDBDBDB);
  static const Color inputBgLight = Color(0xFFEFEFEF);
  static const Color onlineDot = Color(0xFF44D662);
  static const Color verifiedBlue = Color(0xFF0095F6);
  static const Color likeRed = Color(0xFFED4956);

  // Dark Mode Colors
  static const Color bgDark = Color(0xFF000000);
  static const Color bubbleReceivedDark = Color(0xFF262626);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFA8A8A8);
  static const Color separatorDark = Color(0xFF262626);
  static const Color inputBgDark = Color(0xFF1C1C1E);
  static const Color surfaceDark = Color(0xFF1C1C1E);

  // Gradients
  static const List<Color> storyGradient = [
    Color(0xFFF58529),
    Color(0xFFDD2A7B),
    Color(0xFF8134AF),
    Color(0xFF515BD4),
  ];

  static const List<Color> sentGradient = [
    Color(0xFF4F5BD5),
    Color(0xFF962FBF),
    Color(0xFFD62976),
    Color(0xFFFA7E1E),
  ];

  // Typography
  static const String fontFamily = 'SF-Pro';

  static TextStyle usernameStyle(BuildContext context, bool isDark) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: isDark ? textPrimaryDark : textPrimaryLight,
    decoration: TextDecoration.none,
  );

  static TextStyle statusStyle(BuildContext context, {bool isOnline = false, bool isDark = false}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: isOnline ? onlineDot : (isDark ? textSecondaryDark : textSecondaryLight),
    decoration: TextDecoration.none,
  );

  static TextStyle messageStyle(bool isSent, bool isDark) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: isSent ? Color(0xFFFFFFFF) : (isDark ? textPrimaryDark : textPrimaryLight),
    decoration: TextDecoration.none,
  );

  static TextStyle captionStyle(bool isDark) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: isDark ? textSecondaryDark : textSecondaryLight,
    decoration: TextDecoration.none,
  );

  static TextStyle dateDividerStyle(bool isDark) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: isDark ? textSecondaryDark : textSecondaryLight,
    decoration: TextDecoration.none,
  );
}
