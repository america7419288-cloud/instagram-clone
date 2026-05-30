// lib/shared/widgets/ios_app_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// iOS style navigation bar using native CupertinoNavigationBar
/// to enable smooth native iOS hero transitions.
class IOSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? previousTitle; // shown in back button
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool hasLargeTitle;
  final ScrollController? scrollController;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? titleColor;
  final bool translucent; // glassmorphism effect

  const IOSAppBar({
    super.key,
    required this.title,
    this.previousTitle,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.hasLargeTitle = false,
    this.scrollController,
    this.leading,
    this.backgroundColor,
    this.titleColor,
    this.translucent = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = backgroundColor ??
        (isDark
            ? Colors.black.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8));

    final Color tColor = titleColor ?? (isDark ? Colors.white : Colors.black);

    // Build trailing/actions widget
    Widget? trailingWidget;
    if (actions != null && actions!.isNotEmpty) {
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: actions!,
      );
    }

    // Build leading back button
    Widget? leadingWidget = leading;
    if (leadingWidget == null && showBackButton) {
      leadingWidget = CupertinoNavigationBarBackButton(
        previousPageTitle: previousTitle,
        color: const Color(0xFF007AFF), // iOS blue
        onPressed: onBackPressed ?? () => Navigator.of(context).maybePop(),
      );
    }

    return CupertinoNavigationBar(
      backgroundColor: bgColor,
      border: Border(
        bottom: BorderSide(
          color: isDark ? const Color(0xFF38383A) : const Color(0xFFE0E0E0),
          width: 0.5,
        ),
      ),
      automaticallyImplyLeading: false,
      leading: leadingWidget,
      middle: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: tColor,
          fontFamily: 'SF-Pro',
          letterSpacing: -0.3,
        ),
      ),
      trailing: trailingWidget,
    );
  }
}
