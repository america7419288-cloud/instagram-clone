// lib/core/router/main_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'app_router.dart';
import 'navigation_extensions.dart';

// ─── CURRENT TAB INDEX PROVIDER ─────────────────────────────
// Track which bottom nav tab is selected
final currentTabIndexProvider = NotifierProvider<CurrentTabIndex, int>(
  CurrentTabIndex.new,
);

class CurrentTabIndex extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

// ─── MAIN SHELL WIDGET ──────────────────────────────────────
// Wraps all main screens with bottom navigation
class MainShell extends ConsumerWidget {
  final Widget child; // Current active page

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabIndexProvider);

    return Scaffold(
      body: Stack(
        children: [
          child,
          const Align(
            alignment: Alignment.topCenter,
            child: OfflineBanner(),
          ),
        ],
      ),
      // ─── BOTTOM NAVIGATION BAR ──────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.white,
          elevation: 0,
          selectedItemColor: AppColors.textPrimary,
          unselectedItemColor: AppColors.textSecondary,
          showSelectedLabels: false,
          showUnselectedLabels: false,

          items: const [
            // 0: Home
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            // 1: Search
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              activeIcon: Icon(Icons.search),
              label: 'Search',
            ),
            // 2: Create (middle button - special)
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined),
              activeIcon: Icon(Icons.add_box),
              label: 'Create',
            ),
            // 3: Notifications
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              activeIcon: Icon(Icons.favorite),
              label: 'Activity',
            ),
            // 4: Profile
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],

          onTap: (index) => _onTabTapped(context, ref, index),
        ),
      ),
    );
  }

  // ─── HANDLE TAB TAPS ────────────────────────────────────
  void _onTabTapped(BuildContext context, WidgetRef ref, int index) {
    // Create tab: goes to create post (not a tab destination)
    if (index == 2) {
      context.pushIfNotCurrent(AppRoutes.createPost);
      return; // Don't update tab index for create
    }

    // Update current tab index
    ref.read(currentTabIndexProvider.notifier).setIndex(index);

    // Navigate to correct route
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.search);
        break;
      case 3:
        context.go(AppRoutes.notifications);
        break;
      case 4:
        // Get current username from auth state
        final user = ref.read(authProvider).user;
        if (user != null) {
          context.go('/profile/${user.username}');
        }
        break;
    }
  }
}
