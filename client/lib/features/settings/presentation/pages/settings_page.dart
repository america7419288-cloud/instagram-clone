// lib/features/settings/presentation/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import 'change_password_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),

      body: ListView(
        children: [
          // ─── ACCOUNT ─────────────────────────────────────
          _SectionHeader(title: 'Account'),

          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            onTap: () => context.push(AppRoutes.editProfile),
          ),

          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ChangePasswordPage(),
              ),
            ),
          ),

          _SettingsTile(
            icon: Icons.bookmark_outline,
            title: 'Saved Posts',
            onTap: () => AppSnackbar.info(context, 'Saved posts coming soon!'),
          ),

          _SettingsTile(
            icon: Icons.archive_outlined,
            title: 'Archive',
            subtitle: 'Stories, posts you\'ve archived',
            onTap: () => AppSnackbar.info(context, 'Archive coming soon!'),
          ),

          const _SectionDivider(),

          // ─── APPEARANCE ───────────────────────────────────
          _SectionHeader(title: 'Appearance'),

          // Dark Mode Toggle
          _SettingsSwitchTile(
            icon: isDark ? Icons.dark_mode : Icons.light_mode,
            title: 'Dark Mode',
            subtitle: isDark ? 'Dark theme active' : 'Light theme active',
            value: isDark,
            onChanged: (_) =>
                ref.read(themeProvider.notifier).toggleDarkMode(),
          ),

          const _SectionDivider(),

          // ─── NOTIFICATIONS ────────────────────────────────
          _SectionHeader(title: 'Notifications'),

          _SettingsSwitchTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            subtitle: 'Receive push notifications',
            value: true, // Will connect to real settings later
            onChanged: (value) => AppSnackbar.info(
              context,
              value ? 'Notifications enabled' : 'Notifications disabled',
            ),
          ),

          _SettingsSwitchTile(
            icon: Icons.email_outlined,
            title: 'Email Notifications',
            subtitle: 'Receive email updates',
            value: false,
            onChanged: (value) {},
          ),

          const _SectionDivider(),

          // ─── PRIVACY ──────────────────────────────────────
          _SectionHeader(title: 'Privacy'),

          _SettingsSwitchTile(
            icon: Icons.lock_outline,
            title: 'Private Account',
            subtitle: currentUser?.isPrivate == true
                ? 'Only approved followers can see your posts'
                : 'Anyone can see your posts',
            value: currentUser?.isPrivate ?? false,
            onChanged: (value) {
              AppSnackbar.info(
                context,
                value ? 'Account set to private' : 'Account set to public',
              );
              // TODO: Call update profile API
            },
          ),

          _SettingsTile(
            icon: Icons.block_outlined,
            title: 'Blocked Accounts',
            onTap: () =>
                AppSnackbar.info(context, 'Blocked accounts coming soon!'),
          ),

          _SettingsTile(
            icon: Icons.visibility_off_outlined,
            title: 'Activity Status',
            subtitle: 'Allow accounts you follow to see when you\'re active',
            onTap: () {},
          ),

          const _SectionDivider(),

          // ─── SECURITY ─────────────────────────────────────
          _SectionHeader(title: 'Security'),

          _SettingsTile(
            icon: Icons.security_outlined,
            title: 'Two-Factor Authentication',
            onTap: () => AppSnackbar.info(context, '2FA coming soon!'),
          ),

          _SettingsTile(
            icon: Icons.devices_outlined,
            title: 'Login Activity',
            onTap: () =>
                AppSnackbar.info(context, 'Login activity coming soon!'),
          ),

          const _SectionDivider(),

          // ─── HELP ─────────────────────────────────────────
          _SectionHeader(title: 'Help'),

          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Help Center',
            onTap: () {},
          ),

          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Version 1.0.0',
            onTap: () => _showAboutDialog(context),
          ),

          _SettingsTile(
            icon: Icons.flag_outlined,
            title: 'Report a Problem',
            onTap: () {},
          ),

          const _SectionDivider(),

          // ─── ACCOUNT ACTIONS ──────────────────────────────
          _SectionHeader(title: 'Account'),

          // Log Out (red)
          _SettingsTile(
            icon: Icons.logout,
            title: 'Log Out',
            titleColor: AppColors.secondary,
            iconColor: AppColors.secondary,
            onTap: () => _handleLogout(context, ref),
          ),

          // Delete Account (red)
          _SettingsTile(
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account',
            titleColor: AppColors.secondary,
            iconColor: AppColors.secondary,
            onTap: () => _showDeleteAccountDialog(context),
          ),

          const SizedBox(height: 40),

          // App version footer
          Center(
            child: Text(
              'Instagram Clone v1.0.0',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface
                    .withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── LOGOUT ─────────────────────────────────────────────
  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
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
  }

  // ─── DELETE ACCOUNT DIALOG ───────────────────────────────
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Account'),
        content: const Text(
          'This action is permanent and cannot be undone. '
          'All your posts, stories, and data will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─── ABOUT DIALOG ────────────────────────────────────────
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Instagram Clone',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: AppColors.instagramGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.camera_alt,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: const [
        Text(
          'A full-stack Instagram clone built with '
          'Flutter + Node.js + PostgreSQL.',
        ),
      ],
    );
  }
}

// ─── SECTION HEADER ──────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface
              .withOpacity(0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── SETTINGS TILE ───────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ??
            Theme.of(context).colorScheme.onSurface,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ??
              Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.5),
                fontSize: 13,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withOpacity(0.3),
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 2,
      ),
    );
  }
}

// ─── SETTINGS SWITCH TILE ────────────────────────────────────
class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.5),
                fontSize: 13,
              ),
            )
          : null,
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 2,
      ),
    );
  }
}

// ─── SECTION DIVIDER ─────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Theme.of(context)
          .colorScheme
          .onSurface
          .withOpacity(0.1),
    );
  }
}
