// lib/features/menu/presentation/three_dot_menu.dart

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/menu_action.dart';
import '../models/menu_context.dart';
import '../controllers/menu_controller.dart';
import 'widgets/menu_sheet.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// THEME
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class InstagramMenuTheme {
  static const fontFamily = 'SFPro';
  
  static const background = Color(0xFFFFFFFF);
  static const backgroundDark = Color(0xFF1C1C1E);
  
  static const sectionDivider = Color(0xFFEFEFEF);
  static const sectionDividerDark = Color(0xFF2C2C2C);
  
  static const sectionGap = Color(0xFFF2F2F7);
  static const sectionGapDark = Color(0xFF000000);
  
  static const text = Color(0xFF000000);
  static const textDark = Color(0xFFFFFFFF);
  
  static const textSecondary = Color(0xFF8E8E93);
  static const textSecondaryDark = Color(0xFF8E8E93);
  
  static const destructive = Color(0xFFFF3B30);
  static const primary = Color(0xFF007AFF);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ENTRY POINT
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class InstagramMenu {
  static Future<void> show(
    BuildContext context, {
    required MenuContext menuContext,
    Function(MenuAction)? onAction,
  }) async {
    // Provide haptic feedback on open
    HapticFeedback.mediumImpact();

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => MenuSheet(
        menuContext: menuContext,
        onAction: onAction,
      ),
    );
  }
}
