import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:instagram_client/core/theme/app_theme.dart';
import '../providers/browser_provider.dart';

class BrowserToolbar extends StatelessWidget {
  final BrowserProvider provider;
  final bool isDark;
  final VoidCallback onClose;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback onOpenExternal;

  const BrowserToolbar({
    super.key,
    required this.provider,
    required this.isDark,
    required this.onClose,
    required this.onShare,
    required this.onMore,
    required this.onOpenExternal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
              ? const Color(0xFF38383A)
              : const Color(0xFFE0E0E0),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarButton(
            icon: CupertinoIcons.arrow_left,
            enabled: provider.canGoBack,
            isDark: isDark,
            onTap: provider.goBack,
          ),
          _ToolbarButton(
            icon: CupertinoIcons.arrow_right,
            enabled: provider.canGoForward,
            isDark: isDark,
            onTap: provider.goForward,
          ),
          _ToolbarButton(
            icon: CupertinoIcons.share,
            enabled: true,
            isDark: isDark,
            onTap: onShare,
          ),
          _ToolbarButton(
            icon: CupertinoIcons.book,
            enabled: true,
            isDark: isDark,
            onTap: () => _showBookmarkAdd(context),
          ),
          _ToolbarButton(
            icon: CupertinoIcons.ellipsis,
            enabled: true,
            isDark: isDark,
            onTap: onMore,
          ),
        ],
      ),
    );
  }

  void _showBookmarkAdd(BuildContext context) {
    HapticFeedback.mediumImpact();
    _showBookmarkSavedToast(context);
  }

  void _showBookmarkSavedToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              CupertinoIcons.bookmark_fill,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'Bookmark saved',
              style: TextStyle(decoration: TextDecoration.none, color: Colors.white),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.black87,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final bool isDark;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: 100.ms);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled
        ? (_) => _ctrl.forward()
        : null,
      onTapUp: widget.enabled
        ? (_) {
            _ctrl.reverse();
            HapticFeedback.lightImpact();
            widget.onTap();
          }
        : null,
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.8).animate(_ctrl),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 22,
            color: widget.enabled
              ? (widget.isDark ? Colors.white : Colors.black)
              : (widget.isDark
                  ? Colors.white24
                  : Colors.black26),
          ),
        ),
      ),
    );
  }
}
