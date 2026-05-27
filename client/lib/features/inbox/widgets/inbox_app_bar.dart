// lib/features/inbox/widgets/inbox_app_bar.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoColors;
import 'package:flutter_lucide/flutter_lucide.dart';

class InboxAppBar extends StatefulWidget {
  final String username;
  final double scrollOffset;
  final VoidCallback onBackTap;
  final VoidCallback onComposeTap;
  final VoidCallback? onDropdownTap;
  final VoidCallback onCommunitiesTap;

  const InboxAppBar({
    super.key,
    required this.username,
    required this.scrollOffset,
    required this.onBackTap,
    required this.onComposeTap,
    this.onDropdownTap,
    required this.onCommunitiesTap,
  });

  @override
  State<InboxAppBar> createState() => _InboxAppBarState();
}

class _InboxAppBarState extends State<InboxAppBar> {
  bool _isDropdownOpen = false;

  void _handleDropdownTap() {
    setState(() {
      _isDropdownOpen = !_isDropdownOpen;
    });
    if (widget.onDropdownTap != null) {
      widget.onDropdownTap!();
    } else {
      // Default: show account switcher bottom sheet
      _showAccountSwitcherBottomSheet(context);
    }
  }

  void _showAccountSwitcherBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.withValues(alpha: 0.3),
                  child: const Icon(LucideIcons.user),
                ),
                title: Text(
                  widget.username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.check_circle, color: Color(0xFF0095F6)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const CircleAvatar(
                  radius: 20,
                  child: Icon(LucideIcons.plus),
                ),
                title: const Text('Add Account'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isDropdownOpen = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Colors.black;
    final iconColor = Colors.white;

    // Fade out username title as scrollOffset goes past 20.
    final double titleOpacity =
        (1.0 - (widget.scrollOffset / 20.0)).clamp(0.0, 1.0);

    return Container(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── LEFT: back button ──────────────────────────
              Positioned(
                left: 8,
                child: GestureDetector(
                  onTap: widget.onBackTap,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.back,
                          color: CupertinoColors.activeBlue,
                          size: 26,
                        ),
                        SizedBox(width: 2),
                        Text(
                          'Instagram',
                          style: TextStyle(
                            color: CupertinoColors.activeBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'SF Pro Text',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── CENTER: username + dropdown ────────────────
              Opacity(
                opacity: titleOpacity,
                child: GestureDetector(
                  onTap: _handleDropdownTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.5,
                        ),
                        child: Text(
                          widget.username,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                            letterSpacing: -0.3,
                            fontFamily: 'SF Pro Text',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _isDropdownOpen ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          LucideIcons.chevron_down,
                          color: iconColor,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── RIGHT: action buttons ──────────────────────
              Positioned(
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: widget.onCommunitiesTap,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 4.0),
                        child: Icon(
                          CupertinoIcons.group,
                          color: iconColor,
                          size: 26,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onComposeTap,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(
                            left: 10.0, right: 16.0, top: 4.0, bottom: 4.0),
                        child: Icon(
                          CupertinoIcons.create,
                          color: iconColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
