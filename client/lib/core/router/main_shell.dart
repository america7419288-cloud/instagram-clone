// lib/core/router/main_shell.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/reels/presentation/pages/reels_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../shared/widgets/spring_widget.dart';

/// Tracks the currently selected tab index globally so other widgets
/// can read or reset it (e.g. after creating a post).
class MainShellTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  set state(int value) => super.state = value;
}

final mainShellTabIndexProvider = NotifierProvider<MainShellTabIndexNotifier, int>(MainShellTabIndexNotifier.new);

class HomeScrollSignalNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

final homeScrollSignalProvider = NotifierProvider<HomeScrollSignalNotifier, int>(HomeScrollSignalNotifier.new);

class ProfileScrollSignalNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

final profileScrollSignalProvider = NotifierProvider<ProfileScrollSignalNotifier, int>(ProfileScrollSignalNotifier.new);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  // Keep pages alive when switching tabs
  final List<GlobalKey> _tabKeys = List.generate(5, (_) => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;

    final Color bgColor = isDark
        ? Colors.black.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.9);

    final Color borderColor = isDark
        ? const Color(0xFF262626)
        : const Color(0xFFDBDBDB);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          KeyedSubtree(key: _tabKeys[0], child: const HomePage()),
          KeyedSubtree(key: _tabKeys[1], child: const SearchPage()),
          KeyedSubtree(key: _tabKeys[2], child: const ReelsPage()),
          KeyedSubtree(key: _tabKeys[3], child: const NotificationsPage()),
          KeyedSubtree(
            key: _tabKeys[4],
            child: ProfilePage(username: user?.username ?? ''),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: borderColor, width: 0.3),
          ),
        ),
        child: CupertinoTabBar(
          backgroundColor: bgColor,
          border: const Border(), // We handle border via parent Container
          activeColor: isDark ? Colors.white : Colors.black,
          inactiveColor: isDark ? Colors.white : Colors.black,
          currentIndex: _currentIndex,
          iconSize: 26.0,
          onTap: (index) {
            if (index == _currentIndex) {
              // Double tap or re-tap logic
              if (index == 0) {
                ref.read(homeScrollSignalProvider.notifier).increment();
              } else if (index == 4) {
                ref.read(profileScrollSignalProvider.notifier).increment();
              }
            }
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = index);
            ref.read(mainShellTabIndexProvider.notifier).state = index;
          },
          items: [
            _buildTabItem(
              isActive: _currentIndex == 0,
              activeIcon: PhosphorIcons.house(PhosphorIconsStyle.fill),
              inactiveIcon: PhosphorIcons.house(PhosphorIconsStyle.bold),
            ),
            _buildTabItem(
              isActive: _currentIndex == 1,
              activeIcon: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill),
              inactiveIcon: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
            ),
            _buildTabItem(
              isActive: _currentIndex == 2,
              activeIcon: PhosphorIcons.play(PhosphorIconsStyle.fill),
              inactiveIcon: PhosphorIcons.play(PhosphorIconsStyle.bold),
            ),
            _buildTabItem(
              isActive: _currentIndex == 3,
              activeIcon: PhosphorIcons.heart(PhosphorIconsStyle.fill),
              inactiveIcon: PhosphorIcons.heart(PhosphorIconsStyle.bold),
            ),
            BottomNavigationBarItem(
              icon: _buildProfileIcon(
                user?.profilePicUrl,
                _currentIndex == 4,
                isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildTabItem({
    required bool isActive,
    required IconData activeIcon,
    required IconData inactiveIcon,
  }) {
    return BottomNavigationBarItem(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: Icon(
          isActive ? activeIcon : inactiveIcon,
          key: ValueKey(isActive),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildProfileIcon(String? url, bool isActive, bool isDark) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isActive
            ? Border.all(
                color: isDark ? Colors.white : Colors.black,
                width: 1.5,
              )
            : null,
      ),
      child: Padding(
        padding: isActive ? const EdgeInsets.all(1.0) : EdgeInsets.zero,
        child: CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFFDBDBDB),
          backgroundImage: url != null ? NetworkImage(url) : null,
          child: url == null
              ? const Icon(CupertinoIcons.person_fill,
                  size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
