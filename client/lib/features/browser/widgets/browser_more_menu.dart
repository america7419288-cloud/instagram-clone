import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:instagram_client/core/theme/app_theme.dart';
import '../providers/browser_provider.dart';

class BrowserMoreMenu extends StatelessWidget {
  final BrowserProvider provider;
  final bool isDark;
  final VoidCallback onFindInPage;
  final VoidCallback onDesktopMode;
  final VoidCallback onReaderMode;
  final VoidCallback onCopyLink;
  final VoidCallback onOpenExternal;
  final VoidCallback onHistory;

  const BrowserMoreMenu({
    super.key,
    required this.provider,
    required this.isDark,
    required this.onFindInPage,
    required this.onDesktopMode,
    required this.onReaderMode,
    required this.onCopyLink,
    required this.onOpenExternal,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                ? const Color(0xFF48484A)
                : const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Quick action grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickAction(
                  icon: CupertinoIcons.doc_on_doc,
                  label: 'Copy',
                  isDark: isDark,
                  onTap: onCopyLink,
                ),
                _QuickAction(
                  icon: CupertinoIcons.square_arrow_up_on_square,
                  label: 'Open External',
                  isDark: isDark,
                  onTap: onOpenExternal,
                ),
                _QuickAction(
                  icon: CupertinoIcons.textformat,
                  label: 'Reader',
                  isDark: isDark,
                  isActive: provider.isReaderMode,
                  onTap: onReaderMode,
                ),
                _QuickAction(
                  icon: CupertinoIcons.desktopcomputer,
                  label: 'Desktop',
                  isDark: isDark,
                  isActive: provider.isDesktopMode,
                  onTap: onDesktopMode,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(
            height: 0.5,
            color: isDark
              ? const Color(0xFF38383A)
              : const Color(0xFFE0E0E0),
          ),

          // List items
          _MoreMenuItem(
            icon: CupertinoIcons.search,
            label: 'Find on page',
            isDark: isDark,
            onTap: onFindInPage,
          ),
          _MoreMenuItem(
            icon: CupertinoIcons.clock,
            label: 'History',
            isDark: isDark,
            onTap: onHistory,
          ),
          _MoreMenuItem(
            icon: CupertinoIcons.printer,
            label: 'Print',
            isDark: isDark,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction>
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
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.88).animate(_ctrl),
        child: Column(
          children: [
            AnimatedContainer(
              duration: 200.ms,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: widget.isActive
                  ? AppColors.iosBlue.withOpacity(0.15)
                  : (widget.isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF2F2F7)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                widget.icon,
                size: 24,
                color: widget.isActive
                  ? AppColors.iosBlue
                  : (widget.isDark
                      ? Colors.white
                      : Colors.black),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 64,
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  color: widget.isDark
                    ? Colors.white70
                    : Colors.black87,
                  fontSize: 11,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MoreMenuItem> createState() => _MoreMenuItemState();
}

class _MoreMenuItemState extends State<_MoreMenuItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: 80.ms,
        color: _pressed
          ? (widget.isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05))
          : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 20,
              color: widget.isDark ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(width: 14),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
                fontSize: 15,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
