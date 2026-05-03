// lib/core/router/main_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/notifications/presentation/pages/providers/notification_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  // ─── Routes matching bottom nav order ─────────────────
  final List<String> _routes = [
    '/home',
    '/search',
    '/reels',         // ← Reels replaces placeholder
    '/notifications',
    '/my-profile',
  ];

  late List<AnimationController> _tabControllers;
  late List<Animation<double>> _tabScales;

  @override
  void initState() {
    super.initState();
    _tabControllers = List.generate(
      5,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 150),
      ),
    );
    _tabScales = _tabControllers
        .map(
          (c) => Tween<double>(begin: 1.0, end: 0.75).animate(
            CurvedAnimation(parent: c, curve: Curves.easeInOut),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final c in _tabControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;

    _tabControllers[index].forward().then(
          (_) => _tabControllers[index].reverse(),
        );

    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    
    // Using unreadCountProvider from notification_provider.dart
    final unreadNotifications = ref.watch(unreadCountProvider);

    // ─── Reels page: black bottom nav ─────────────────
    final isReelsTab = _currentIndex == 2;
    final navBgColor = isReelsTab
        ? Colors.black
        : (isDark ? AppColors.darkBackground : AppColors.background);
    final navBorderColor = isReelsTab
        ? Colors.white12
        : (isDark ? AppColors.darkDivider : AppColors.divider);
    final activeIconColor = isReelsTab
        ? Colors.white
        : (isDark ? AppColors.darkIconPrimary : AppColors.iconPrimary);
    final inactiveIconColor = isReelsTab
        ? Colors.white60
        : (isDark ? AppColors.darkIconSecondary : AppColors.iconSecondary);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBgColor,
          border: Border(
            top: BorderSide(color: navBorderColor, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 49,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // ─── Home ──────────────────────────────
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  index: 0,
                  currentIndex: _currentIndex,
                  controller: _tabControllers[0],
                  scale: _tabScales[0],
                  activeColor: activeIconColor,
                  inactiveColor: inactiveIconColor,
                  onTap: _onTap,
                ),
                // ─── Search ────────────────────────────
                _NavItem(
                  icon: Icons.search,
                  activeIcon: Icons.search,
                  index: 1,
                  currentIndex: _currentIndex,
                  controller: _tabControllers[1],
                  scale: _tabScales[1],
                  activeColor: activeIconColor,
                  inactiveColor: inactiveIconColor,
                  onTap: _onTap,
                ),
                // ─── Reels (center) ────────────────────
                _NavItem(
                  icon: Icons.play_circle_outline,
                  activeIcon: Icons.play_circle_filled,
                  index: 2,
                  currentIndex: _currentIndex,
                  controller: _tabControllers[2],
                  scale: _tabScales[2],
                  activeColor: activeIconColor,
                  inactiveColor: inactiveIconColor,
                  onTap: _onTap,
                ),
                // ─── Notifications ─────────────────────
                _NavItem(
                  icon: Icons.favorite_outline,
                  activeIcon: Icons.favorite,
                  index: 3,
                  currentIndex: _currentIndex,
                  controller: _tabControllers[3],
                  scale: _tabScales[3],
                  activeColor: activeIconColor,
                  inactiveColor: inactiveIconColor,
                  onTap: _onTap,
                  badgeCount: unreadNotifications,
                ),
                // ─── Profile ───────────────────────────
                _NavItem(
                  index: 4,
                  currentIndex: _currentIndex,
                  controller: _tabControllers[4],
                  scale: _tabScales[4],
                  activeColor: activeIconColor,
                  inactiveColor: inactiveIconColor,
                  onTap: _onTap,
                  avatarUrl: user?.profilePicUrl,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// NAV ITEM WIDGET
// ─────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData? icon;
  final IconData? activeIcon;
  final int index;
  final int currentIndex;
  final AnimationController controller;
  final Animation<double> scale;
  final Color activeColor;
  final Color inactiveColor;
  final void Function(int) onTap;
  final int badgeCount;
  final String? avatarUrl;

  const _NavItem({
    this.icon,
    this.activeIcon,
    required this.index,
    required this.currentIndex,
    required this.controller,
    required this.scale,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    this.badgeCount = 0,
    this.avatarUrl,
  });

  bool get isActive => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 49,
        child: Center(
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, child) => Transform.scale(
              scale: scale.value,
              child: child,
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // ─── Avatar tab (profile) ──────────────
                if (index == 4)
                  _AvatarTab(
                    avatarUrl: avatarUrl,
                    isActive: isActive,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                  )
                else
                  // ─── Icon tab ─────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isActive ? activeIcon : icon,
                      key: ValueKey(isActive),
                      size: 26,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  ),

                // ─── Badge ────────────────────────────
                if (badgeCount > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _Badge(count: badgeCount),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Avatar Tab ───────────────────────────────────────
class _AvatarTab extends StatelessWidget {
  final String? avatarUrl;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;

  const _AvatarTab({
    required this.avatarUrl,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? activeColor : Colors.transparent,
          width: 2,
        ),
        image: avatarUrl != null
            ? DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
        color: const Color(0xFFDBDBDB),
      ),
      child: avatarUrl == null
          ? Icon(
              Icons.person,
              size: 16,
              color: isActive ? activeColor : inactiveColor,
            )
          : null,
    );
  }
}

// ─── Badge ────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 1.5,
        ),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
