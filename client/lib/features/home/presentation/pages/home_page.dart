// lib/features/home/presentation/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/pages/login_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.white,

      // ─── APP BAR ──────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.instagramGradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: const Text(
            'Instagram',
            style: TextStyle(
              fontSize: 28,
              fontFamily: 'Billabong',
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          // Notifications icon
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.favorite_border,
              color: AppColors.textPrimary,
            ),
          ),
          // Messages icon
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.send_outlined,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),

      // ─── BODY ─────────────────────────────────────────────
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, color: AppColors.border),

            // ─── WELCOME CARD ──────────────────────────────
            _buildWelcomeCard(user),

            const SizedBox(height: 16),

            // ─── PLACEHOLDER FEED ──────────────────────────
            _buildPlaceholderFeed(),
          ],
        ),
      ),

      // ─── BOTTOM NAVIGATION ────────────────────────────────
      bottomNavigationBar: _buildBottomNav(context, ref),
    );
  }

  // ─── WELCOME CARD ─────────────────────────────────────────
  Widget _buildWelcomeCard(user) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Auth System Complete! ✅',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // User info
          if (user != null) ...[
            _infoRow('👤 Username', '@${user.username}'),
            _infoRow('📧 Email', user.email),
            _infoRow('📝 Full Name', user.fullName),
            _infoRow(
              '🔒 Account Type',
              user.isPrivate ? 'Private' : 'Public',
            ),
            _infoRow(
              '✔️ Verified',
              user.isVerified ? 'Yes' : 'No',
            ),
          ],

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '🚧 Home Feed coming on Day 12!\n'
              'Currently building backend APIs...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── PLACEHOLDER FEED POSTS ───────────────────────────────
  Widget _buildPlaceholderFeed() {
    return Column(
      children: List.generate(
        3,
        (index) => _buildPlaceholderPost(index),
      ),
    );
  }

  Widget _buildPlaceholderPost(int index) {
    final colors = [
      const Color(0xFF833AB4),
      const Color(0xFFFD1D1D),
      const Color(0xFF405DE6),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Row(
            children: [
              // Avatar placeholder
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors[index].withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors[index],
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.person,
                  size: 20,
                  color: colors[index],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.shimmer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 60,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.shimmer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(
                Icons.more_horiz,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),

        // Post image placeholder
        Container(
          width: double.infinity,
          height: 300,
          color: colors[index].withOpacity(0.1),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 60,
                  color: colors[index].withOpacity(0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Post ${index + 1} - Coming Day 12',
                  style: TextStyle(
                    color: colors[index].withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Post actions
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Row(
            children: [
              const Icon(Icons.favorite_border, size: 26),
              const SizedBox(width: 16),
              const Icon(Icons.chat_bubble_outline, size: 24),
              const SizedBox(width: 16),
              const Icon(Icons.send_outlined, size: 24),
              const Spacer(),
              const Icon(Icons.bookmark_border, size: 24),
            ],
          ),
        ),

        // Likes count placeholder
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.shimmer,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Caption placeholder
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.shimmer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  // ─── BOTTOM NAVIGATION BAR ────────────────────────────────
  Widget _buildBottomNav(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.white,
        elevation: 0,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textSecondary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            activeIcon: Icon(Icons.add_box),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          if (index == 4) {
            // Profile tab → show user options
            _showProfileOptions(context, ref);
          }
        },
      ),
    );
  }

  // ─── PROFILE OPTIONS (including logout) ───────────────────
  void _showProfileOptions(BuildContext context, WidgetRef ref) {
    final user = ref.read(authProvider).user;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // User info
              if (user != null) ...[
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.border,
                  backgroundImage: user.profilePicUrl != null
                      ? NetworkImage(user.profilePicUrl!)
                      : null,
                  child: user.profilePicUrl == null
                      ? Text(
                          user.username[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),

              // Menu items
              _buildMenuItem(
                icon: Icons.person_outline,
                label: 'View Profile',
                onTap: () {
                  Navigator.pop(context);
                  // Will navigate to profile page on Day 12
                },
              ),
              _buildMenuItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              _buildMenuItem(
                icon: Icons.logout,
                label: 'Log Out',
                color: AppColors.secondary,
                onTap: () async {
                  Navigator.pop(context);
                  await _handleLogout(context, ref);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? AppColors.textPrimary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  // ─── HANDLE LOGOUT ────────────────────────────────────────
  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      // Call logout
      await ref.read(authProvider.notifier).logout();

      if (context.mounted) {
        // Navigate to login and clear all routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }
}