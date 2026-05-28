// lib/shared/widgets/ios_app_bar.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Exact iOS navigation bar with:
/// - Animated back button with previous page title
/// - Title slides in/out with page transition
/// - Large title mode (collapses on scroll)
/// - iOS blue color scheme
class IOSAppBar extends StatefulWidget implements PreferredSizeWidget {
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
  Size get preferredSize => Size.fromHeight(
    hasLargeTitle ? 100 : kToolbarHeight,
  );

  @override
  State<IOSAppBar> createState() => _IOSAppBarState();
}

class _IOSAppBarState extends State<IOSAppBar>
    with SingleTickerProviderStateMixin {

  // Title animation controllers
  late AnimationController _titleController;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleOpacity;

  // Large title scroll
  double _scrollOffset = 0;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();

    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOutCubic,
    ));

    _titleOpacity = Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ));

    // Animate title in on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleController.forward();
    });

    // Listen to scroll for large title collapse
    widget.scrollController?.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = widget.scrollController!.offset;
    setState(() => _scrollOffset = offset);

    final shouldCollapse = offset > 44;
    if (shouldCollapse != _isCollapsed) {
      setState(() => _isCollapsed = shouldCollapse);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = widget.backgroundColor ??
      (isDark
        ? Colors.black.withOpacity(0.85)
        : Colors.white.withOpacity(0.85));

    final titleColor = widget.titleColor ??
      (isDark ? Colors.white : Colors.black);

    return ClipRect(
      child: BackdropFilter(
        filter: widget.translucent
          ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
          : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Container(
          color: bgColor,
          child: SafeArea(
            bottom: false,
            child: widget.hasLargeTitle
              ? _buildLargeTitleBar(isDark, titleColor)
              : _buildStandardBar(isDark, titleColor),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardBar(bool isDark, Color titleColor) {
    return SizedBox(
      height: kToolbarHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── CENTER TITLE ──────────────────────────
          SlideTransition(
            position: _titleSlide,
            child: FadeTransition(
              opacity: _titleOpacity,
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // ── LEFT: BACK BUTTON ─────────────────────
          Positioned(
            left: 0,
            child: _buildBackButton(isDark),
          ),

          // ── RIGHT: ACTIONS ────────────────────────
          if (widget.actions != null)
            Positioned(
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: widget.actions!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLargeTitleBar(bool isDark, Color titleColor) {
    return Column(
      children: [
        // Standard top bar
        SizedBox(
          height: kToolbarHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Small title (shows when scrolled)
              AnimatedOpacity(
                opacity: _isCollapsed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedSlide(
                  offset: _isCollapsed
                    ? Offset.zero
                    : const Offset(0, 0.3),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                child: _buildBackButton(isDark),
              ),

              if (widget.actions != null)
                Positioned(
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.actions!,
                  ),
                ),
            ],
          ),
        ),

        // Large title (hides when scrolled)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _isCollapsed ? 0 : 44,
          child: AnimatedOpacity(
            opacity: _isCollapsed ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16, bottom: 8, right: 16
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton(bool isDark) {
    if (!widget.showBackButton) {
      return widget.leading ?? const SizedBox.shrink();
    }

    // Check if we can pop
    final canPop = Navigator.of(context).canPop();
    if (!canPop && widget.leading == null) {
      return const SizedBox.shrink();
    }

    return _IOSBackButton(
      previousTitle: widget.previousTitle,
      isDark: isDark,
      onPressed: () {
        if (widget.onBackPressed != null) {
          widget.onBackPressed!();
        } else {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }
}

// ── iOS BACK BUTTON ─────────────────────────────────
class _IOSBackButton extends StatefulWidget {
  final String? previousTitle;
  final bool isDark;
  final VoidCallback onPressed;

  const _IOSBackButton({
    this.previousTitle,
    required this.isDark,
    required this.onPressed,
  });

  @override
  State<_IOSBackButton> createState() => _IOSBackButtonState();
}

class _IOSBackButtonState extends State<_IOSBackButton>
    with SingleTickerProviderStateMixin {

  late AnimationController _pressController;
  late Animation<double> _pressOpacity;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressOpacity = Tween<double>(begin: 1.0, end: 0.4)
      .animate(_pressController);
  }

  // Truncate previous title to fit iOS style
  String _truncateTitle(String? title) {
    if (title == null || title.isEmpty) return 'Back';
    if (title.length <= 12) return title;
    return '${title.substring(0, 11)}…';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _pressOpacity,
        builder: (_, child) => Opacity(
          opacity: _pressOpacity.value,
          child: child,
        ),
        child: Container(
          height: kToolbarHeight,
          padding: const EdgeInsets.only(left: 8, right: 16),
          constraints: const BoxConstraints(maxWidth: 160),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // iOS chevron icon (slightly bold)
              const Icon(
                CupertinoIcons.chevron_back,
                color: Color(0xFF007AFF), // iOS blue
                size: 22,
              ),

              // Previous page title
              if (widget.previousTitle != null) ...[
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    _truncateTitle(widget.previousTitle),
                    style: const TextStyle(
                      color: Color(0xFF007AFF),
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }
}
