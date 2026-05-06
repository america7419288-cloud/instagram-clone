// lib/features/auth/presentation/widgets/account_switcher_sheet.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/saved_account_model.dart';
import '../providers/auth_provider.dart';
import '../../../../core/router/app_router.dart';

class AccountSwitcherSheet extends ConsumerStatefulWidget {
  const AccountSwitcherSheet({super.key});

  @override
  ConsumerState<AccountSwitcherSheet> createState() =>
      _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState
    extends ConsumerState<AccountSwitcherSheet> {
  String? _switchingToId;

  Future<void> _switchAccount(
    BuildContext context,
    String userId,
  ) async {
    setState(() => _switchingToId = userId);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(authProvider.notifier).switchAccount(userId);

      if (mounted) {
        Navigator.pop(context);
        // ─── Navigate to home and refresh ─────────────
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:  Text('Failed to switch: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _switchingToId = null);
    }
  }

  Future<void> _removeAccount(
    BuildContext context,
    WidgetRef ref,
    SavedAccountModel account,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title:   const Text('Remove account?'),
        content: Text(
          'Remove @${account.username} from saved accounts?\n\nYou will need to log in again to access this account.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child:     const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    await ref.read(authProvider.notifier).removeAccount(account.userId);

    // ─── If no accounts left → go to login ────────────
    final remaining = ref.read(authProvider).savedAccounts;
    if (remaining.isEmpty && mounted) {
      Navigator.pop(context);
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final accounts  = authState.savedAccounts;
    final activeId  = authState.user?.id;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Handle ─────────────────────────────────
          Container(
            width:  36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            decoration: BoxDecoration(
              color:        isDark
                  ? AppColors.darkDivider
                  : AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ─── Title ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical:   12,
            ),
            child: Row(
              children: [
                Text(
                  'Switch Account',
                  style: TextStyle(
                    fontSize:   17,
                    fontWeight: FontWeight.w700,
                    color:      isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color:      AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 0.5,
            color: isDark ? AppColors.darkDivider : AppColors.divider,
          ),

          // ─── Account list ────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap:      true,
              physics:         const ClampingScrollPhysics(),
              itemCount:       accounts.length,
              separatorBuilder: (_, __) => Divider(
                height:  0.5,
                indent:  72,
                color:   isDark ? AppColors.darkDivider : AppColors.divider,
              ),
              itemBuilder: (context, index) {
                final account  = accounts[index];
                final isActive = account.userId == activeId;
                final isSwitching = _switchingToId == account.userId;

                return _AccountTile(
                  account:     account,
                  isActive:    isActive,
                  isSwitching: isSwitching,
                  isDark:      isDark,
                  onTap:       isActive || isSwitching
                      ? null
                      : () => _switchAccount(context, account.userId),
                  onRemove:    () => _removeAccount(
                    context,
                    ref,
                    account,
                  ),
                );
              },
            ),
          ),

          Divider(
            height: 0.5,
            color: isDark ? AppColors.darkDivider : AppColors.divider,
          ),

          // ─── Add account button ───────────────────────
          ListTile(
            leading: Container(
              width:  44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppColors.darkDivider
                      : AppColors.divider,
                  width: 1.5,
                ),
              ),
              child: Icon(
                PhosphorIcons.plus(),
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
                size: 20,
              ),
            ),
            title: Text(
              'Add account',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color:      isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/add-account');
            },
          ),

          // ─── Log out all ─────────────────────────────
          if (accounts.length > 1)
            ListTile(
              leading: Container(
                width:  44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withValues(alpha: 0.1),
                ),
                child: Icon(
                  PhosphorIcons.signOut(),
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              title: const Text(
                'Log out of all accounts',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:      AppColors.error,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authProvider.notifier).logoutAll();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),

          SafeArea(
            top: false,
            child: const SizedBox(height: 8),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final SavedAccountModel account;
  final bool              isActive;
  final bool              isSwitching;
  final bool              isDark;
  final VoidCallback?     onTap;
  final VoidCallback      onRemove;

  const _AccountTile({
    required this.account,
    required this.isActive,
    required this.isSwitching,
    required this.isDark,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap:    onTap,
      leading:  Stack(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isDark
                ? AppColors.darkDivider
                : AppColors.divider,
            backgroundImage: account.profilePicture != null
                ? CachedNetworkImageProvider(account.profilePicture!)
                : null,
            child: account.profilePicture == null
                ? Text(
                    account.username[0].toUpperCase(),
                    style: TextStyle(
                      fontSize:   18,
                      fontWeight: FontWeight.w700,
                      color:      isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  )
                : null,
          ),

          if (isActive)
            Positioned(
              right:  0,
              bottom: 0,
              child: Container(
                width:  16,
                height: 16,
                decoration: BoxDecoration(
                  color:  AppColors.primary,
                  shape:  BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.background,
                    width: 2,
                  ),
                ),
                child: Icon(
                  PhosphorIcons.check(PhosphorIconsStyle.bold),
                  color: Colors.white,
                  size:  10,
                ),
              ),
            ),
        ],
      ),

      title: Text(
        account.username,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color:      isDark
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary,
        ),
      ),

      subtitle: Text(
        isActive ? 'Active' : account.email,
        style: TextStyle(
          fontSize: 13,
          color:    isActive
              ? AppColors.primary
              : (isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary),
        ),
      ),

      trailing: isSwitching
          ? const SizedBox(
              width:  20,
              height: 20,
              child: CupertinoActivityIndicator(
                radius: 8,
                color: AppColors.primary,
              ),
            )
          : isActive
              ? null
              : GestureDetector(
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      PhosphorIcons.minusCircle(),
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
    );
  }
}

void showAccountSwitcher(BuildContext context) {
  showModalBottomSheet(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder:            (_) => const AccountSwitcherSheet(),
  );
}
