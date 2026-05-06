// lib/shared/widgets/in_app_notification_banner.dart

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

class InAppNotificationBanner extends StatefulWidget {
  final String  title;
  final String  body;
  final String? avatarUrl;
  final String? username;
  final VoidCallback? onTap;
  final Duration duration;

  const InAppNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    this.avatarUrl,
    this.username,
    this.onTap,
    this.duration = const Duration(seconds: 4),
  });

  // ─── Static show method ───────────────────────────────
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    String? avatarUrl,
    String? username,
    VoidCallback? onTap,
  }) {
    // ─── Dismiss existing banner ─────────────────────────
    _currentEntry?.remove();
    _currentEntry = null;

    HapticFeedback.lightImpact();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => InAppNotificationBanner(
        title:     title,
        body:      body,
        avatarUrl: avatarUrl,
        username:  username,
        onTap: () {
          entry.remove();
          _currentEntry = null;
          onTap?.call();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    // ─── Auto-dismiss after duration ─────────────────────
    Timer(const Duration(seconds: 4), () {
      if (entry.mounted) {
        entry.remove();
        if (_currentEntry == entry) _currentEntry = null;
      }
    });
  }

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState
    extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve:  Curves.easeOutCubic,
    ));

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // ─── Auto-dismiss animation ───────────────────────
    Timer(widget.duration - const Duration(milliseconds: 350), () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) ==
        Brightness.dark;

    return Positioned(
      top:   0,
      left:  0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: GestureDetector(
                onTap: widget.onTap,
                onVerticalDragEnd: (d) {
                  if (d.primaryVelocity != null &&
                      d.primaryVelocity! < -200) {
                    _controller.reverse();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical:   12,
                  ),
                  decoration: BoxDecoration(
                    color:        isDark
                        ? AppColors.darkSurface.withValues(alpha: 0.97)
                        : AppColors.background.withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:      Colors.black.withValues(
                          alpha: isDark ? 0.4 : 0.15,
                        ),
                        blurRadius: 20,
                        offset:     const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.divider,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // ─── Avatar ────────────────────────
                      _buildAvatar(isDark),
                      const SizedBox(width: 12),

                      // ─── Title + body ──────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize:       MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize:   14,
                                fontWeight: FontWeight.w700,
                                color:      isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                              maxLines:  1,
                              overflow:  TextOverflow.ellipsis,
                            ),
                            if (widget.body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.body,
                                style: TextStyle(
                                  fontSize: 13,
                                  color:    isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary,
                                  height:  1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // ─── Instagram icon ────────────────
                      const SizedBox(width: 8),
                      Container(
                        width:  36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.storyStart,
                              AppColors.storyMid,
                              AppColors.storyEnd,
                            ],
                            begin: Alignment.bottomLeft,
                            end:   Alignment.topRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size:  18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    if (widget.avatarUrl != null) {
      return CircleAvatar(
        radius:          22,
        backgroundImage: CachedNetworkImageProvider(widget.avatarUrl!),
        backgroundColor: isDark
            ? AppColors.darkDivider
            : AppColors.divider,
      );
    }

    return CircleAvatar(
      radius:          22,
      backgroundColor: isDark
          ? AppColors.darkDivider
          : AppColors.divider,
      child: Text(
        widget.username?.isNotEmpty == true
            ? widget.username![0].toUpperCase()
            : '?',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color:      isDark
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary,
        ),
      ),
    );
  }
}
