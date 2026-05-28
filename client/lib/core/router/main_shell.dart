// lib/core/router/main_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/glass_bottom_nav.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/reels/presentation/pages/reels_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/inbox/pages/inbox_page.dart';
import '../../features/chat/presentation/providers/chat_notifiers.dart';

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────

class MainShellTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  @override
  set state(int value) => super.state = value;
}

final mainShellTabIndexProvider =
    NotifierProvider<MainShellTabIndexNotifier, int>(
        MainShellTabIndexNotifier.new);

class HomeScrollSignalNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

final homeScrollSignalProvider =
    NotifierProvider<HomeScrollSignalNotifier, int>(
        HomeScrollSignalNotifier.new);

class ProfileScrollSignalNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

final profileScrollSignalProvider =
    NotifierProvider<ProfileScrollSignalNotifier, int>(
        ProfileScrollSignalNotifier.new);

// ─────────────────────────────────────────────────────────────
// MAIN SHELL
// ─────────────────────────────────────────────────────────────

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  // 5 tabs: Home(0) Search(1) Reels(2) Inbox(3) Profile(4)
  final List<GlobalKey> _tabKeys = List.generate(5, (_) => GlobalKey());

  void _onTabTapped(int index) {
    final currentIndex = ref.read(mainShellTabIndexProvider);
    // Double-tap scroll-to-top
    if (index == currentIndex) {
      if (index == 0) ref.read(homeScrollSignalProvider.notifier).increment();
      if (index == 4) ref.read(profileScrollSignalProvider.notifier).increment();
    }
    ref.read(mainShellTabIndexProvider.notifier).state = index;
  }

  // ── Build nav items ────────────────────────────────────
  List<GlassNavItem> _buildNavItems(
      bool isDark, String? avatarUrl, int totalUnread) {
    return [
      // 0 — Home
      GlassNavItem(
        builder: (isActive, isDark) => buildSvgNavItem(
          isActive: isActive,
          isDark: isDark,
          inactiveAsset: 'assets/icons/24/Home.svg',
          activeAsset: 'assets/icons/24/Home (Filled).svg',
          size: 28,
        ),
      ),

      // 1 — Search / Explore
      GlassNavItem(
        builder: (isActive, isDark) => buildSvgNavItem(
          isActive: isActive,
          isDark: isDark,
          inactiveAsset: 'assets/icons/24/Search.svg',
          activeAsset: 'assets/icons/24/Search (Filled).svg',
          size: 28,
        ),
      ),

      // 2 — Reels
      GlassNavItem(
        builder: (isActive, isDark) => buildSvgNavItem(
          isActive: isActive,
          isDark: isDark,
          inactiveAsset: 'assets/icons/24/Reels.svg',
          activeAsset: 'assets/icons/24/Reels (Filled).svg',
          size: 28,
        ),
      ),

      // 3 — Inbox (with unread badge)
      GlassNavItem(
        badgeCount: totalUnread > 0 ? totalUnread : null,
        builder: (isActive, isDark) => buildSvgNavItem(
          isActive: isActive,
          isDark: isDark,
          inactiveAsset: 'assets/icons/24/Share.svg', // paper airplane icon for DM
          activeAsset: 'assets/icons/24/Share.svg',
          size: 28,
        ),
      ),

      // 4 — Profile (avatar with animated ring)
      GlassNavItem(
        builder: (isActive, isDark) => buildProfileNavItem(
          isActive: isActive,
          isDark: isDark,
          avatarUrl: avatarUrl,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final totalUnread = ref.watch(totalUnreadCountProvider);
    final currentIndex = ref.watch(mainShellTabIndexProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: IndexedStack(
          index: currentIndex,
          children: [
            KeyedSubtree(key: _tabKeys[0], child: const SafeArea(bottom: false, child: HomePage())),
            KeyedSubtree(key: _tabKeys[1], child: const SafeArea(bottom: false, child: SearchPage())),
            KeyedSubtree(key: _tabKeys[2], child: const ReelsPage()),
            KeyedSubtree(key: _tabKeys[3], child: const SafeArea(bottom: false, child: InboxPage())),
            KeyedSubtree(
              key: _tabKeys[4],
              child: SafeArea(bottom: false, child: ProfilePage(username: user?.username ?? '')),
            ),
          ],
        ),
        bottomNavigationBar: GlassBottomNav(
          currentIndex: currentIndex,
          onTap: _onTabTapped,
          items: _buildNavItems(isDark, user?.profilePicUrl, totalUnread),
          style: BottomNavStyle.fullWidth,
          indicatorStyle: IndicatorStyle.dot,
        ),
      ),
    );
  }
}
