// lib/core/router/main_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  // ─── Routes (index 2 = create, handled separately) ───
  final List<String?> _routes = [
    '/home',
    '/search',
    null,             // index 2 = "+" opens sheet
    '/reels',
    '/notifications',
    '/my-profile',
  ];

  late List<AnimationController> _tabControllers;
  late List<Animation<double>> _tabScales;

  @override
  void initState() {
    super.initState();
    _tabControllers = List.generate(
      6,
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

  // ─── Handle tap ───────────────────────────────────────
  void _onTap(int index) {
    // ─── "+" button → show create sheet ───────────────
    if (index == 2) {
      _tabControllers[index].forward().then(
            (_) => _tabControllers[index].reverse(),
          );
      HapticFeedback.lightImpact();
      _showCreateSheet();
      return;
    }

    if (index == _currentIndex) return;

    _tabControllers[index].forward().then(
          (_) => _tabControllers[index].reverse(),
        );

    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    final route = _routes[index];
    if (route != null) context.go(route);
  }

  // ─────────────────────────────────────────────────────
  // CREATE CHOICE SHEET
  // ─────────────────────────────────────────────────────
  void _showCreateSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateChoiceSheet(
        isDark: isDark,
        onPost: () {
          Navigator.pop(context);
          context.push('/create');
        },
        onReel: () {
          Navigator.pop(context);
          context.push('/create-reel');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final unreadNotifications =
        ref.watch(unreadNotificationsCountProvider).asData?.value ?? 0;

    // ─── Reels tab index = 3 ──────────────────────────
    final isReelsTab = _currentIndex == 3;

    final navBg = isReelsTab
        ? Colors.black
        : (isDark ? AppColors.darkBackground : AppColors.background);
    final navBorder = isReelsTab
        ? Colors.white12
        : (isDark ? AppColors.darkDivider : AppColors.divider);
    final activeColor = isReelsTab
        ? Colors.white
        : (isDark ? AppColors.darkIconPrimary : AppColors.iconPrimary);
    final inactiveColor = isReelsTab
        ? Colors.white60
        : (isDark
            ? AppColors.darkIconSecondary
            : AppColors.iconSecondary);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(color: navBorder, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 49,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // ─── Home ────────────────────────────
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  index: 0,
                  currentIndex: _currentIndex,
                  controller: _tabControllers[0],
                  scale: _tabScales[0],
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  onTap: _onTap,
                ),

                // ─── Search ──────────────────────────
                _NavItem(
                  icon: Icons.search,
                  activeIcon: Icons.search,
                  index: 1,
                  currentIndex: _currentIndex,
                  controller: _tabControllers[1],
                  scale: _tabScales[1],
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  onTap: _onTap,
                ),

                // ─── Create "+" (center) ──────────────
                _CreateButton(
                  controller: _tabControllers[2],
                  scale: _tabScales[2],
                  onTap: () => _onTap(2),
                  isReelsTab: isReelsTab,
                ),

                // ─── Reels ────────────────────────────
                _NavItem(
                  icon: Icons.play_circle_outline,
                  activeIcon: Icons.play_circle_filled,
                  index: 3,
                  currentIndex: _currentIndex,
                  controller: _tabControllers[3],
                  scale: _tabScales[3],
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  onTap: _onTap,
                ),

                // ─── Notifications ────────────────────
                _NavItem(
                  icon: Icons.favorite_outline,
                  activeIcon: Icons.favorite,
                  index: 4,
                  currentIndex: _currentIndex,
                  controller: _tabControllers[4],
                  scale: _tabScales[4],
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  onTap: _onTap,
                  badgeCount: unreadNotifications,
                ),

                // ─── Profile ──────────────────────────
                _NavItem(
                  index: 5,
                  currentIndex: _currentIndex,
                  controller: _tabControllers[5],
                  scale: _tabScales[5],
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  onTap: _onTap,
                  avatarUrl: user?.profilePicture,
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
// CREATE BUTTON (center "+" with box style)
// ─────────────────────────────────────────────────────
class _CreateButton extends StatelessWidget {
  final AnimationController controller;
  final Animation<double> scale;
  final VoidCallback onTap;
  final bool isReelsTab;

  const _CreateButton({
    required this.controller,
    required this.scale,
    required this.onTap,
    required this.isReelsTab,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            child: Container(
              width: 34,
              height: 26,
              decoration: BoxDecoration(
                color: isReelsTab
                    ? Colors.white.withOpacity(0.9)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isReelsTab
                      ? Colors.white
                      : const Color(0xFF262626),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.add,
                size: 18,
                color: isReelsTab
                    ? Colors.black
                    : const Color(0xFF262626),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// CREATE CHOICE SHEET
// ─────────────────────────────────────────────────────
class _CreateChoiceSheet extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPost;
  final VoidCallback onReel;

  const _CreateChoiceSheet({
    required this.isDark,
    required this.onPost,
    required this.onReel,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        isDark ? AppColors.darkSurface : AppColors.background;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final divColor =
        isDark ? AppColors.darkDivider : AppColors.divider;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Handle ──────────────────────────────────
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            decoration: BoxDecoration(
              color: divColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ─── Title ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Create',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),

          Divider(height: 1, color: divColor),

          // ─── Post option ─────────────────────────────
          _CreateOption(
            icon: Icons.grid_on_outlined,
            iconBg: const Color(0xFFE91E63),
            title: 'Post',
            subtitle: 'Share a photo or multiple photos',
            onTap: onPost,
            isDark: isDark,
          ),

          Divider(height: 1, color: divColor, indent: 72),

          // ─── Reel option ─────────────────────────────
          _CreateOption(
            icon: Icons.play_circle_outline,
            iconBg: const Color(0xFF9C27B0),
            title: 'Reel',
            subtitle: 'Share a short video up to 90 seconds',
            onTap: onReel,
            isDark: isDark,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// CREATE OPTION ROW
// ─────────────────────────────────────────────────────
class _CreateOption extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const _CreateOption({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.chevron_right,
              color: subColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// NAV ITEM (unchanged from before)
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
        width: 50,
        height: 49,
        child: Center(
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, child) =>
                Transform.scale(scale: scale.value, child: child),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Avatar tab
                if (index == 5)
                  _AvatarTab(
                    avatarUrl: avatarUrl,
                    isActive: isActive,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                  )
                else
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isActive ? activeIcon : icon,
                      key: ValueKey(isActive),
                      size: 26,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  ),

                // Badge
                if (badgeCount > 0)
                  Positioned(
                    top: 2,
                    right: 2,
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
