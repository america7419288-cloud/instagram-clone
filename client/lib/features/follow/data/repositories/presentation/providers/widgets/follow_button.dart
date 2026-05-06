// lib/features/follow/presentation/widgets/follow_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../shared/widgets/app_snackbar.dart';
import '../follow_provider.dart';
import '../../../../../../../shared/widgets/spring_widget.dart';


// ─── FOLLOW BUTTON ──────────────────────────────────────────
// Reusable widget used everywhere (profile, search, suggestions)
class FollowButton extends ConsumerWidget {
  final String targetUserId;
  final bool compact;   // Smaller version for lists

  const FollowButton({
    super.key,
    required this.targetUserId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followState = ref.watch(followProvider(targetUserId));

    if (followState.isOwnProfile) return const SizedBox.shrink();
    if (followState.hasBlockedMe) return const SizedBox.shrink();

    return _buildButton(context, ref, followState);
  }

  Widget _buildButton(
    BuildContext context,
    WidgetRef ref,
    FollowState followState,
  ) {
    final isLoading = followState.isLoading;

    // ─── BLOCKED button (filled blue)
    if (followState.isBlocked) {
      return BouncyTap(
        onTap: isLoading ? null : () => _handleUnblock(context, ref),
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          constraints: BoxConstraints(minWidth: compact ? 0 : 88),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? _loadingIndicator(Colors.white)
              : Text(
                  'Unblock',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }

    // ─── FOLLOWING button (outlined)
    if (followState.isFollowing) {
      return BouncyTap(
        onTap: isLoading
            ? null
            : () => _handleToggle(context, ref, followState),
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          constraints: BoxConstraints(minWidth: compact ? 0 : 88),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? _loadingIndicator(AppColors.textPrimary)
              : Text(
                  'Following',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }

    // ─── REQUESTED button (outlined, lighter)
    if (followState.isPending) {
      return BouncyTap(
        onTap: isLoading
            ? null
            : () => _handleToggle(context, ref, followState),
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          constraints: BoxConstraints(minWidth: compact ? 0 : 88),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? _loadingIndicator(AppColors.textSecondary)
              : Text(
                  'Requested',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }

    // ─── FOLLOW button (filled blue)
    return BouncyTap(
      onTap: isLoading
          ? null
          : () => _handleToggle(context, ref, followState),
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        constraints: BoxConstraints(minWidth: compact ? 0 : 88),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: isLoading
            ? _loadingIndicator(Colors.white)
            : Text(
                'Follow',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _loadingIndicator(Color color) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
      ),
    );
  }

  Future<void> _handleToggle(
    BuildContext context,
    WidgetRef ref,
    FollowState followState,
  ) async {
    // Show unfollow confirmation if following
    if (followState.isFollowing) {
      final confirmed = await _showUnfollowDialog(context);
      if (!confirmed) return;
    }

    try {
      await ref
          .read(followProvider(targetUserId).notifier)
          .toggleFollow();
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  Future<bool> _showUnfollowDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Unfollow?'),
        content: const Text(
          'Are you sure you want to unfollow this person?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
            ),
            child: const Text(
              'Unfollow',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleUnblock(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(followProvider(targetUserId).notifier).unblockUser();
      if (context.mounted) {
        AppSnackbar.success(context, 'User unblocked');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }
}
