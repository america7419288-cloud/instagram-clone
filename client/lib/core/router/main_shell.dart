// lib/core/router/main_shell.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_assets.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/reels/presentation/pages/reels_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/create/presentation/pages/media_picker_page.dart';
import '../../features/create/presentation/pages/creation_camera_page.dart';
import '../../features/messages/presentation/pages/messages_page.dart';
import '../../features/inbox/pages/inbox_page.dart';
import '../../features/chat/presentation/providers/chat_notifiers.dart';

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

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  final List<GlobalKey> _tabKeys = List.generate(5, (_) => GlobalKey());

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      if (index == 0) ref.read(homeScrollSignalProvider.notifier).increment();
      if (index == 4) ref.read(profileScrollSignalProvider.notifier).increment();
    }
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    ref.read(mainShellTabIndexProvider.notifier).state = index;
  }

  void _openCamera() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CreationCameraPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final totalUnread = ref.watch(totalUnreadCountProvider);

    final bgColor = (isDark ? Colors.black : Colors.white).withOpacity(0.94);
    final borderColor = isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB);
    final iconColor = isDark ? Colors.white : Colors.black;

    // Bottom bar: 0=Home 1=Search 2=+(intercepted) 3=Reels 4=Profile
    // IndexedStack pages: 0=Home 1=Search 2=Reels 3=Profile
    final pageIndex = _currentIndex;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
        index: pageIndex,
        children: [
          KeyedSubtree(key: _tabKeys[0], child: const HomePage()),
          KeyedSubtree(key: _tabKeys[1], child: const SearchPage()),
          KeyedSubtree(key: _tabKeys[2], child: const ReelsPage()),
          KeyedSubtree(key: _tabKeys[3], child: const InboxPage()),
          KeyedSubtree(
            key: _tabKeys[4],
            child: ProfilePage(username: user?.username ?? ''),
          ),
        ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: borderColor, width: 0.3)),
        ),
        child: CupertinoTabBar(
          backgroundColor: bgColor,
          border: const Border(),
          activeColor: iconColor,
          inactiveColor: iconColor,
          currentIndex: _currentIndex,
          iconSize: 22.0,
          onTap: _onTabTapped,
          items: [
            // Home
            _tabItem(
              inactive: SvgPicture.asset(AppAssets.homeOutline, width: 23, height: 23, colorFilter: ColorFilter.mode(iconColor.withOpacity(0.6), BlendMode.srcIn)),
              active: SvgPicture.asset(AppAssets.homeOutline, width: 23, height: 23, colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn)),
            ),
            // Search
            _tabItem(
              inactive: SvgPicture.asset(AppAssets.search, width: 24, height: 24, colorFilter: ColorFilter.mode(iconColor.withOpacity(0.6), BlendMode.srcIn)),
              active: SvgPicture.asset(AppAssets.search, width: 24, height: 24, colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn)),
            ),
            // Reels
            _tabItem(
              inactive: SvgPicture.asset(AppAssets.getIcon('Tab=Reels', isDark: isDark, type: 'Default'), width: 29, height: 29, colorFilter: ColorFilter.mode(iconColor.withOpacity(0.6), BlendMode.srcIn)),
              active: SvgPicture.asset(AppAssets.getIcon('Tab=Reels', isDark: isDark, type: 'Selected'), width: 29, height: 29, colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn)),
            ),
            // Inbox (Send Icon)
            _tabItem(
              inactive: _buildInboxIcon(isDark, iconColor.withOpacity(0.6), totalUnread, false),
              active: _buildInboxIcon(isDark, iconColor, totalUnread, true),
            ),
            // Profile
            BottomNavigationBarItem(
              icon: _profileIcon(user?.profilePicUrl, false, isDark, iconColor),
              activeIcon: _profileIcon(user?.profilePicUrl, true, isDark, iconColor),
            ),
          ],
        ),
      ),
      ));
  }

  BottomNavigationBarItem _tabItem(
      {required Widget inactive, required Widget active}) {
    return BottomNavigationBarItem(icon: inactive, activeIcon: active);
  }

  Widget _profileIcon(
      String? url, bool isActive, bool isDark, Color iconColor) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isActive
            ? Border.all(color: iconColor, width: 1.5)
            : null,
      ),
      child: Padding(
        padding: isActive ? const EdgeInsets.all(1.0) : EdgeInsets.zero,
        child: CircleAvatar(
          radius: 13,
          backgroundColor: const Color(0xFFDBDBDB),
          backgroundImage: url != null ? NetworkImage(url) : null,
          child: url == null
              ? SvgPicture.asset(
                  AppAssets.getIcon('Tab=Profile', isDark: isDark, type: isActive ? 'Selected' : 'Default'),
                  width: 25,
                  height: 25,
                  colorFilter: ColorFilter.mode(isDark ? Colors.white : Colors.black, BlendMode.srcIn),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildInboxIcon(bool isDark, Color color, int badgeCount, bool isActive) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SvgPicture.asset(
          AppAssets.getIcon('Name=Share', isDark: isDark, state: isActive ? 'Active' : 'Default'),
          width: 25,
          height: 25,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3040),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.black : Colors.white,
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Creation Sheet ────────────────────────────────────────
class _CreateSheet extends StatelessWidget {
  final VoidCallback onPost, onReel, onStory;

  const _CreateSheet(
      {required this.onPost, required this.onReel, required this.onStory});

  @override
  Widget build(BuildContext context) {
    final safeBot = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Create',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF-Pro')),
          ),
          const Divider(color: Color(0xFF3A3A3C), height: 0.5),
          _SheetOption(
            icon: LucideIcons.image,
            label: 'Post',
            sub: 'Share photos and videos',
            onTap: () { Navigator.pop(context); onPost(); },
          ),
          const Divider(color: Color(0xFF3A3A3C), height: 0.5),
          _SheetOption(
            icon: LucideIcons.clapperboard,
            label: 'Reel',
            sub: 'Create a short video',
            onTap: () { Navigator.pop(context); onReel(); },
          ),
          const Divider(color: Color(0xFF3A3A3C), height: 0.5),
          _SheetOption(
            icon: LucideIcons.circle_dashed,
            label: 'Story',
            sub: 'Share a photo or video',
            onTap: () { Navigator.pop(context); onStory(); },
          ),
          const Divider(color: Color(0xFF3A3A3C), height: 0.5),
          CupertinoButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontFamily: 'SF-Pro')),
          ),
          SizedBox(height: safeBot),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final VoidCallback onTap;

  const _SheetOption(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      onPressed: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'SF-Pro')),
              Text(sub,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      fontFamily: 'SF-Pro')),
            ],
          ),
          const Spacer(),
          const Icon(LucideIcons.chevron_right,
              color: Colors.white38, size: 18),
        ],
      ),
    );
  }
}
