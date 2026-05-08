// lib/core/design/design_tokens.dart

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────
// SPACING (8px grid)
// ─────────────────────────────────────────────────────
class Spacing {
  Spacing._();
  static const double xxs = 2;
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
  static const double x3l = 32;
  static const double x4l = 40;
  static const double x5l = 48;
  static const double x6l = 64;
}

// ─────────────────────────────────────────────────────
// RADIUS
// ─────────────────────────────────────────────────────
class Radii {
  Radii._();
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double full = 999;

  static BorderRadius get xsAll   => BorderRadius.circular(xs);
  static BorderRadius get smAll   => BorderRadius.circular(sm);
  static BorderRadius get mdAll   => BorderRadius.circular(md);
  static BorderRadius get lgAll   => BorderRadius.circular(lg);
  static BorderRadius get xlAll   => BorderRadius.circular(xl);
  static BorderRadius get fullAll => BorderRadius.circular(full);
}

// ─────────────────────────────────────────────────────
// ANIMATION DURATIONS
// ─────────────────────────────────────────────────────
class Durations {
  Durations._();
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast    = Duration(milliseconds: 150);
  static const Duration short   = Duration(milliseconds: 200);
  static const Duration normal  = Duration(milliseconds: 250);
  static const Duration medium  = Duration(milliseconds: 300);
  static const Duration long    = Duration(milliseconds: 400);
  static const Duration slow    = Duration(milliseconds: 500);
  static const Duration xSlow  = Duration(milliseconds: 700);
}

// ─────────────────────────────────────────────────────
// ANIMATION CURVES
// ─────────────────────────────────────────────────────
class Curves2 {
  Curves2._();
  static const Curve standard   = Curves.easeInOut;
  static const Curve decelerate = Curves.decelerate;
  static const Curve spring     = Curves.elasticOut;
  static const Curve overshoot  = Curves.easeOutBack;
  static const Curve sharp      = Curves.easeInOutCubic;
  static const Curve ios        = Curves.easeInOutCubic;
}

// ─────────────────────────────────────────────────────
// COLORS (Complete)
// ─────────────────────────────────────────────────────
class IgColors {
  IgColors._();

  // Brand
  static const Color primary     = Color(0xFF0095F6);
  static const Color primaryDark = Color(0xFF0074CC);
  static const Color accent      = Color(0xFFE1306C);
  static const Color like        = Color(0xFFFF3040);
  static const Color online      = Color(0xFF00C853);
  static const Color verified    = Color(0xFF0095F6);
  static const Color error       = Color(0xFFFF3040);
  static const Color success     = Color(0xFF00C853);

  // Story gradient
  static const Color storyA      = Color(0xFFFCAF45);
  static const Color storyB      = Color(0xFFE1306C);
  static const Color storyC      = Color(0xFF833AB4);
  static const Color storySeen   = Color(0xFFDBDBDB);
  static const Color storySeenDk = Color(0xFF363636);

  // Light mode
  static const Color bg          = Color(0xFFFFFFFF);
  static const Color bgAlt       = Color(0xFFFAFAFA);
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color divider     = Color(0xFFDBDBDB);
  static const Color dividerLight = Color(0xFFF0F0F0);
  static const Color text        = Color(0xFF262626);
  static const Color textSub     = Color(0xFF737373);
  static const Color textHint    = Color(0xFFBBBBBB);
  static const Color inputBg     = Color(0xFFEFEFEF);
  static const Color icon        = Color(0xFF262626);

  // Dark mode
  static const Color darkBg       = Color(0xFF000000);
  static const Color darkBgAlt    = Color(0xFF121212);
  static const Color darkSurface  = Color(0xFF1C1C1C);
  static const Color darkSurfaceE = Color(0xFF2A2A2A);
  static const Color darkDivider  = Color(0xFF262626);
  static const Color darkText     = Color(0xFFFFFFFF);
  static const Color darkTextSub  = Color(0xFFA8A8A8);
  static const Color darkTextHint = Color(0xFF555555);
  static const Color darkInputBg  = Color(0xFF262626);
  static const Color darkIcon     = Color(0xFFFFFFFF);

  // Shimmer
  static const Color shimBase     = Color(0xFFEFEFEF);
  static const Color shimHigh     = Color(0xFFF8F8F8);
  static const Color darkShimBase = Color(0xFF2A2A2A);
  static const Color darkShimHigh = Color(0xFF3D3D3D);

  // Static helpers
  static Color bg_(bool dark)       => dark ? darkBg       : bg;
  static Color surface_(bool dark)  => dark ? darkSurface  : surface;
  static Color divider_(bool dark)  => dark ? darkDivider  : divider;
  static Color text_(bool dark)     => dark ? darkText     : text;
  static Color textSub_(bool dark)  => dark ? darkTextSub  : textSub;
  static Color icon_(bool dark)     => dark ? darkIcon     : icon;
  static Color inputBg_(bool dark)  => dark ? darkInputBg  : inputBg;
  static Color shimBase_(bool dark) => dark ? darkShimBase : shimBase;
}

// ─────────────────────────────────────────────────────
// TYPOGRAPHY
// ─────────────────────────────────────────────────────
class IgText {
  IgText._();

  static const String sfPro = 'SF-Pro';

  static const TextStyle display = TextStyle(
    fontFamily: sfPro, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5,
  );
  static const TextStyle h1 = TextStyle(
    fontFamily: sfPro, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: sfPro, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2,
  );
  static const TextStyle h3 = TextStyle(
    fontFamily: sfPro, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.1,
  );
  static const TextStyle bodyLg = TextStyle(
    fontFamily: sfPro, fontSize: 16, fontWeight: FontWeight.w400, height: 1.5,
  );
  static const TextStyle body = TextStyle(
    fontFamily: sfPro, fontSize: 15, fontWeight: FontWeight.w400, height: 1.5,
  );
  static const TextStyle bodySm = TextStyle(
    fontFamily: sfPro, fontSize: 14, fontWeight: FontWeight.w400, height: 1.4,
  );
  static const TextStyle labelLg = TextStyle(
    fontFamily: sfPro, fontSize: 16, fontWeight: FontWeight.w600,
  );
  static const TextStyle label = TextStyle(
    fontFamily: sfPro, fontSize: 14, fontWeight: FontWeight.w600,
  );
  static const TextStyle labelSm = TextStyle(
    fontFamily: sfPro, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: sfPro, fontSize: 13, fontWeight: FontWeight.w400,
  );
  static const TextStyle micro = TextStyle(
    fontFamily: sfPro, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.2,
  );
  static const TextStyle username = TextStyle(
    fontFamily: sfPro, fontSize: 15, fontWeight: FontWeight.w700,
  );
  static const TextStyle billabong = TextStyle(
    fontFamily: 'Billabong', fontSize: 32,
  );
}
