// lib/features/settings/presentation/pages/settings_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'saved_posts_page.dart';
import 'notifications_settings_page.dart';
import 'close_friends_page.dart';
import 'muted_accounts_page.dart';
import 'blocked_accounts_page.dart';
import 'archive_page.dart';
import 'privacy_settings_page.dart';
import 'not_interested_page.dart';
import '../../../ads/presentation/providers/ad_provider.dart';
import '../../../ads/presentation/pages/advertiser_register_page.dart';
import '../../../ads/presentation/pages/ad_dashboard_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.isDark;
    final user = authState.user;
    final advertiserState = ref.watch(advertiserProvider);

    // iOS Instagram specific colors
    final Color backgroundColor = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final Color sectionHeaderColor = const Color(0xFF8E8E8E);
    
    // Style for the headers (13pt, uppercase, #8E8E8E)
    final TextStyle headerStyle = TextStyle(
      color: sectionHeaderColor,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.1,
      fontFamily: 'SF-Pro',
    );

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
        middle: const Text(
          'Settings and privacy',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, fontFamily: 'SF-Pro'),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            // ─── SEARCH BAR ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: CupertinoSearchTextField(
                placeholder: 'Search',
                backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // ─── SECTION: YOUR ACCOUNT ────────────────────────
            _buildSectionHeader('Your account', headerStyle),
            CupertinoListSection.insetGrouped(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              backgroundColor: Colors.transparent,
              children: [
                CupertinoListTile(
                  leading: const Icon(LucideIcons.user_round, color: Color(0xFF0095F6), size: 28),
                  title: Row(
                    children: [
                      const Text('Meta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 4),
                      Text('Accounts Center', style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                    ],
                  ),
                  subtitle: const Text('Manage your connected experiences across Meta', style: TextStyle(fontSize: 12)),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () {},
                ),
              ],
            ),

            // ─── SECTION: FOR PROFESSIONALS ───────────────────
            _buildSectionHeader('For professionals', headerStyle),
            CupertinoListSection.insetGrouped(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              backgroundColor: Colors.transparent,
              children: [
                _buildTile(
                  LucideIcons.megaphone,
                  'Ads Manager',
                  () {
                    if (advertiserState.advertiser == null) {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const AdvertiserRegisterPage(),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const AdDashboardPage(),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),

            // ─── SECTION: HOW YOU USE INSTAGRAM ───────────────
            _buildSectionHeader('How you use Instagram', headerStyle),
            CupertinoListSection.insetGrouped(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              backgroundColor: Colors.transparent,
              children: [
                _buildTile(LucideIcons.bookmark, 'Saved', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const SavedPostsPage()))),
                _buildTile(LucideIcons.archive, 'Archive', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const ArchivePage()))),
                _buildTile(LucideIcons.bell, 'Notifications', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const NotificationsSettingsPage()))),
                _buildTile(LucideIcons.shield_check, 'Close Friends', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const CloseFriendsPage()))),
                _buildTile(LucideIcons.volume_x, 'Muted accounts', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const MutedAccountsPage()))),
              ],
            ),

            // ─── SECTION: WHO CAN SEE YOUR CONTENT ────────────
            _buildSectionHeader('Who can see your content', headerStyle),
            CupertinoListSection.insetGrouped(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              backgroundColor: Colors.transparent,
              children: [
                _buildTile(LucideIcons.lock, 'Account Privacy', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const PrivacySettingsPage()))),
                _buildTile(LucideIcons.users, 'Close Friends', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const CloseFriendsPage()))),
                _buildTile(LucideIcons.circle_slash, 'Blocked', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const BlockedAccountsPage()))),
              ],
            ),

            // ─── SECTION: HOW OTHERS CAN INTERACT WITH YOU ────
            _buildSectionHeader('How others can interact with you', headerStyle),
            CupertinoListSection.insetGrouped(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              backgroundColor: Colors.transparent,
              children: [
                _buildTile(LucideIcons.message_circle, 'Messages and story replies', () {}),
                _buildTile(LucideIcons.at_sign, 'Tags and mentions', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const PrivacySettingsPage()))),
                _buildTile(LucideIcons.message_square, 'Comments', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const PrivacySettingsPage()))),
                _buildTile(LucideIcons.repeat, 'Sharing and remixes', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const PrivacySettingsPage()))),
              ],
            ),
 
            // ─── SECTION: WHAT YOU SEE ────────────────────────
            _buildSectionHeader('What you see', headerStyle),
            CupertinoListSection.insetGrouped(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              backgroundColor: Colors.transparent,
              children: [
                _buildTile(LucideIcons.star, 'Favorites', () {}),
                _buildTile(LucideIcons.volume_x, 'Muted accounts', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const MutedAccountsPage()))),
                _buildTile(LucideIcons.lightbulb, 'Suggested content', () {}),
                _buildTile(LucideIcons.eye_off, 'Not interested', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const NotInterestedPage()))),
                _buildTile(LucideIcons.heart, 'Like and share counts', () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const PrivacySettingsPage()))),
              ],
            ),

            // ─── SECTION: YOUR APP AND MEDIA ──────────────────
            _buildSectionHeader('Your app and media', headerStyle),
            CupertinoListSection.insetGrouped(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              backgroundColor: Colors.transparent,
              children: [
                _buildTile(LucideIcons.settings, 'Device permissions', () {}),
                _buildTile(LucideIcons.globe, 'Language', () {}),
                _buildTile(LucideIcons.user, 'Accessibility', () {}),
                _buildTile(LucideIcons.chart_bar, 'Data usage', () {}),
                _buildTile(LucideIcons.download, 'Original posts', () {}),
                _buildTile(LucideIcons.server, 'Server Settings', () => context.push(AppRoutes.serverSettings)),
              ],
            ),

            // ─── SECTION: APPEARANCE (Functional) ─────────────
            _buildSectionHeader('Appearance', headerStyle),
            CupertinoListSection.insetGrouped(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              backgroundColor: Colors.transparent,
              children: [
                CupertinoListTile(
                  leading: const Icon(LucideIcons.moon),
                  title: const Text('Dark mode', style: TextStyle(fontSize: 16)),
                  trailing: CupertinoSwitch(
                    value: isDark,
                    onChanged: (val) => ref.read(themeProvider.notifier).toggleDarkMode(val),
                  ),
                ),
              ],
            ),

            // ─── SECTION: MORE INFO AND SUPPORT ───────────────
            _buildSectionHeader('More info and support', headerStyle),
            CupertinoListSection.insetGrouped(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              backgroundColor: Colors.transparent,
              children: [
                _buildTile(LucideIcons.hand_helping, 'Help', () {}),
                _buildTile(LucideIcons.square_user, 'Account Status', () {}),
                _buildTile(LucideIcons.info, 'About', () {}),
              ],
            ),

            // ─── SECTION: LOGIN ──────────────────────────────
            _buildSectionHeader('Login', headerStyle),
            CupertinoListSection.insetGrouped(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              backgroundColor: Colors.transparent,
              children: [
                CupertinoListTile(
                  title: const Text('Add Account', style: TextStyle(color: Color(0xFF0095F6), fontSize: 16)),
                  onTap: () => context.push(AppRoutes.addAccount),
                ),
                CupertinoListTile(
                  title: const Text('Log Out', style: TextStyle(color: CupertinoColors.destructiveRed, fontSize: 16)),
                  onTap: () => _showLogoutDialog(context, ref, 'all'),
                ),
                CupertinoListTile(
                  title: Text('Log out ${user?.username ?? "account"}', style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 16)),
                  onTap: () => _showLogoutDialog(context, ref, 'current'),
                ),
              ],
            ),

            const SizedBox(height: 64),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: style,
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, VoidCallback onTap) {
    return CupertinoListTile(
      leading: Icon(icon, size: 24),
      title: Text(title, style: const TextStyle(fontSize: 16, fontFamily: 'SF-Pro')),
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref, String type) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Log out?'),
        content: Text(type == 'all' ? 'Log out of all accounts?' : 'Log out of your account?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
