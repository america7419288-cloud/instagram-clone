// lib/core/widgets/glass_bottom_nav.dart
// Premium Glassmorphism Bottom Navigation Bar

import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────

enum BottomNavStyle {
  floating, // pill floating above content
  fullWidth, // touches both sides
  hybrid, // full width with rounded top corners
}

enum IndicatorStyle {
  dot, // small dot below icon
  glow, // glowing circle behind icon
  pill, // sliding rounded rect background
  none, // just icon fill change
}

// ─────────────────────────────────────────────────────────────
// NAV ITEM MODEL
// ─────────────────────────────────────────────────────────────

class GlassNavItem {
  /// Receives (isActive, isDark) — return your icon widget.
  final Widget Function(bool isActive, bool isDark) builder;
  final int? badgeCount;

  const GlassNavItem({
    required this.builder,
    this.badgeCount,
  });
}

// ─────────────────────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────────────────────

class GlassBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavItem> items;
  final BottomNavStyle style;
  final IndicatorStyle indicatorStyle;
  final bool hideOnScroll;
  final ScrollController? scrollController;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.style = BottomNavStyle.hybrid,
    this.indicatorStyle = IndicatorStyle.dot,
    this.hideOnScroll = false,
    this.scrollController,
  });

  @override
  State<GlassBottomNav> createState() => _GlassBottomNavState();
}

class _GlassBottomNavState extends State<GlassBottomNav>
    with TickerProviderStateMixin {
  // ── Entry animation ──────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final Animation<Offset> _entrySlide;
  late final Animation<double> _entryOpacity;

  // ── Hide/show on scroll ──────────────────────────────────
  late final AnimationController _hideCtrl;
  late final Animation<double> _hideOffset;
  late final Animation<double> _hideOpacity;

  // ── Sliding pill indicator ───────────────────────────────
  late final AnimationController _pillCtrl;
  late Animation<double> _pillPos;

  // ── Per-tab tap bounce ───────────────────────────────────
  late final List<AnimationController> _tapCtrl;
  late final List<Animation<double>> _tapScale;

  // ── Scroll tracking ──────────────────────────────────────
  double _lastScroll = 0;
  bool _barVisible = true;

  @override
  void initState() {
    super.initState();
    _setupEntry();
    _setupHide();
    _setupPill();
    _setupTapAnimations();
    _setupScrollListener();
    _playEntry();
  }

  void _setupEntry() {
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
  }

  void _setupHide() {
    _hideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _hideOffset = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _hideCtrl, curve: Curves.easeInOut),
    );
    _hideOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _hideCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
  }

  void _setupPill() {
    _pillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pillPos = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _pillCtrl, curve: Curves.easeInOutCubic),
    );
  }

  void _setupTapAnimations() {
    _tapCtrl = List.generate(
      widget.items.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _tapScale = _tapCtrl.map((ctrl) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.84), weight: 25),
        TweenSequenceItem(tween: Tween(begin: 0.84, end: 1.12), weight: 35),
        TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 40),
      ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }).toList();
  }

  void _setupScrollListener() {
    if (!widget.hideOnScroll) return;
    widget.scrollController?.addListener(_onScroll);
  }

  void _onScroll() {
    final ctrl = widget.scrollController;
    if (ctrl == null) return;
    final offset = ctrl.offset;
    final delta = offset - _lastScroll;
    if (delta > 5 && _barVisible && offset > 80) {
      _hideCtrl.forward();
      _barVisible = false;
    } else if (delta < -5 && !_barVisible) {
      _hideCtrl.reverse();
      _barVisible = true;
    }
    _lastScroll = offset;
  }

  void _playEntry() async {
    await Future.delayed(const Duration(milliseconds: 180));
    if (mounted) _entryCtrl.forward();
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    _tapCtrl[index].forward(from: 0);
    _animatePillTo(index);
    if (!_barVisible) {
      _hideCtrl.reverse();
      _barVisible = true;
    }
    widget.onTap(index);
  }

  void _animatePillTo(int index) {
    if (!mounted) return;
    final w = MediaQuery.of(context).size.width / widget.items.length;
    final from = _pillPos.value;
    final to = index * w;
    _pillPos = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _pillCtrl, curve: Curves.easeInOutCubic),
    );
    _pillCtrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(GlassBottomNav old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _animatePillTo(widget.currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: Listenable.merge([_entryCtrl, _hideCtrl]),
      builder: (context, child) {
        final hideY = _hideOffset.value * (52 + bottom);
        return SlideTransition(
          position: _entrySlide,
          child: FadeTransition(
            opacity: _entryOpacity,
            child: Transform.translate(
              offset: Offset(0, hideY),
              child: Opacity(opacity: _hideOpacity.value, child: child),
            ),
          ),
        );
      },
      child: RepaintBoundary(child: _buildByStyle(isDark, bottom)),
    );
  }

  // ─────────────────────────────────────────────────────────
  // STYLE BUILDERS
  // ─────────────────────────────────────────────────────────

  Widget _buildByStyle(bool isDark, double bottom) {
    switch (widget.style) {
      case BottomNavStyle.floating:
        return _buildFloating(isDark, bottom);
      case BottomNavStyle.fullWidth:
        return _buildFullWidth(isDark, bottom);
      case BottomNavStyle.hybrid:
        return _buildHybrid(isDark, bottom);
    }
  }

  Widget _buildFloating(bool isDark, double bottom) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom : 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [Colors.black.withOpacity(0.85), Colors.black.withOpacity(0.80)]
                    : [Colors.white.withOpacity(0.90), Colors.white.withOpacity(0.84)],
              ),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.65),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.45) : Colors.black.withOpacity(0.10),
                  blurRadius: 40,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _buildItems(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidth(bool isDark, double bottom) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [Colors.black.withOpacity(0.88), Colors.black.withOpacity(0.82)]
                  : [Colors.white.withOpacity(0.92), Colors.white.withOpacity(0.86)],
            ),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.75),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 46, child: _buildItems(isDark)),
              SizedBox(height: bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHybrid(bool isDark, double bottom) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [Colors.black.withOpacity(0.85), Colors.black.withOpacity(0.80)]
                  : [Colors.white.withOpacity(0.90), Colors.white.withOpacity(0.84)],
            ),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.13) : Colors.white.withOpacity(0.92),
                width: 0.5,
              ),
              left: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                width: 0.5,
              ),
              right: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.50) : Colors.black.withOpacity(0.07),
                blurRadius: 40,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 46,
                child: Stack(
                  children: [
                    if (widget.indicatorStyle == IndicatorStyle.pill)
                      _buildSlidingPill(isDark),
                    _buildItems(isDark),
                  ],
                ),
              ),
              SizedBox(height: bottom),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ITEMS ROW
  // ─────────────────────────────────────────────────────────

  Widget _buildItems(bool isDark) {
    return Row(
      children: List.generate(widget.items.length, (i) {
        return Expanded(
          child: _NavItemWidget(
            item: widget.items[i],
            isActive: widget.currentIndex == i,
            isDark: isDark,
            tapScale: _tapScale[i],
            indicatorStyle: widget.indicatorStyle,
            onTap: () => _onTap(i),
          ),
        );
      }),
    );
  }

  Widget _buildSlidingPill(bool isDark) {
    return AnimatedBuilder(
      animation: _pillCtrl,
      builder: (_, __) {
        final itemW = MediaQuery.of(context).size.width / widget.items.length;
        return Positioned(
          left: _pillPos.value + (itemW / 2) - 26,
          top: 8,
          child: Container(
            width: 52,
            height: 30,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _hideCtrl.dispose();
    _pillCtrl.dispose();
    for (final c in _tapCtrl) c.dispose();
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────
// INDIVIDUAL NAV ITEM
// ─────────────────────────────────────────────────────────────

class _NavItemWidget extends StatefulWidget {
  final GlassNavItem item;
  final bool isActive;
  final bool isDark;
  final Animation<double> tapScale;
  final IndicatorStyle indicatorStyle;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.item,
    required this.isActive,
    required this.isDark,
    required this.tapScale,
    required this.indicatorStyle,
    required this.onTap,
  });

  @override
  State<_NavItemWidget> createState() => _NavItemWidgetState();
}

class _NavItemWidgetState extends State<_NavItemWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.isActive ? 1.0 : 0.0,
    );
    _glowOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_NavItemWidget old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      widget.isActive ? _glowCtrl.forward() : _glowCtrl.reverse();
    }
  }

  Color get _activeColor => widget.isDark ? Colors.white : Colors.black;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 46,
        child: AnimatedBuilder(
          animation: widget.tapScale,
          builder: (_, child) =>
              Transform.scale(scale: widget.tapScale.value, child: child),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow indicator
              if (widget.indicatorStyle == IndicatorStyle.glow)
                FadeTransition(
                  opacity: _glowOpacity,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _activeColor.withOpacity(0.09),
                      boxShadow: [
                        BoxShadow(
                          color: _activeColor.withOpacity(0.14),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),

              // Icon + dot
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The item builder handles its own active/inactive state —
                  // no AnimatedSwitcher here, which was causing the flicker.
                  widget.item.builder(widget.isActive, widget.isDark),

                  // Dot indicator
                  if (widget.indicatorStyle == IndicatorStyle.dot)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      margin: const EdgeInsets.only(top: 4),
                      width: widget.isActive ? 4 : 0,
                      height: widget.isActive ? 4 : 0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _activeColor,
                      ),
                    ),
                ],
              ),

              // Badge
              if ((widget.item.badgeCount ?? 0) > 0)
                Positioned(
                  top: 8,
                  right: 10,
                  child: _BadgeWidget(count: widget.item.badgeCount!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────
// BADGE WIDGET
// ─────────────────────────────────────────────────────────────

class _BadgeWidget extends StatefulWidget {
  final int count;
  const _BadgeWidget({required this.count});

  @override
  State<_BadgeWidget> createState() => _BadgeWidgetState();
}

class _BadgeWidgetState extends State<_BadgeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.count > 99 ? '99+' : '${widget.count}';
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: Container(
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFED4956),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFED4956).withOpacity(0.4),
              blurRadius: 6,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────
// PROFILE AVATAR ITEM BUILDER (helper)
// ─────────────────────────────────────────────────────────────

Widget buildProfileNavItem({
  required bool isActive,
  required bool isDark,
  String? avatarUrl,
}) {
  final activeColor = isDark ? Colors.white : Colors.black;
  final inactiveColor =
      isDark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.28);

  return AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    width: isActive ? 30 : 28,
    height: isActive ? 30 : 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: isActive ? activeColor : inactiveColor,
        width: isActive ? 2.2 : 1.4,
      ),
    ),
    child: ClipOval(
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: avatarUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _defaultAvatar(isDark),
            )
          : _defaultAvatar(isDark),
    ),
  );
}

Widget _defaultAvatar(bool isDark) {
  return Container(
    color: isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
    child: Icon(
      Icons.person_rounded,
      size: 15,
      color: isDark ? Colors.white54 : Colors.black38,
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// ICONSAX ICON ITEM BUILDER (helper)
//
// NO AnimatedSwitcher — that was causing the 2-second flicker.
// Instead we use AnimatedOpacity on the inactive icon and a
// direct color + size transition via AnimatedDefaultTextStyle.
// The icon itself just swaps instantly; the color fades smoothly.
// ─────────────────────────────────────────────────────────────

Widget buildIconsaxNavItem({
  required bool isActive,
  required bool isDark,
  required IconData inactiveIcon,
  required IconData activeIcon,
  double size = 24,
}) {
  final activeColor = isDark ? Colors.white : Colors.black;
  final inactiveColor =
      isDark ? Colors.white.withOpacity(0.50) : Colors.black.withOpacity(0.42);

  return Stack(
    alignment: Alignment.center,
    children: [
      // Inactive icon — fades out
      AnimatedOpacity(
        opacity: isActive ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
        child: Icon(inactiveIcon, color: inactiveColor, size: size),
      ),
      // Active icon — fades in
      AnimatedOpacity(
        opacity: isActive ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
        child: Icon(activeIcon, color: activeColor, size: size + 1.5),
      ),
    ],
  );
}

Widget buildSvgNavItem({
  required bool isActive,
  required bool isDark,
  required String inactiveAsset,
  required String activeAsset,
  double size = 24,
}) {
  final activeColor = isDark ? Colors.white : Colors.black;
  final inactiveColor =
      isDark ? Colors.white.withOpacity(0.50) : Colors.black.withOpacity(0.42);

  return Stack(
    alignment: Alignment.center,
    children: [
      AnimatedOpacity(
        opacity: isActive ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
        child: SvgPicture.asset(
          inactiveAsset,
          colorFilter: ColorFilter.mode(inactiveColor, BlendMode.srcIn),
          width: size,
          height: size,
        ),
      ),
      AnimatedOpacity(
        opacity: isActive ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
        child: SvgPicture.asset(
          activeAsset,
          colorFilter: ColorFilter.mode(activeColor, BlendMode.srcIn),
          width: size + 1.5,
          height: size + 1.5,
        ),
      ),
    ],
  );
}

