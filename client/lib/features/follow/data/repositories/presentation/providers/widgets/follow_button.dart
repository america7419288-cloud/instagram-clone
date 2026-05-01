// lib/features/follow/presentation/widgets/follow_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../core/theme/app_theme.dart';
import '../follow_provider.dart';

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

    return _buildButton(context, ref, followState);
  }

  Widget _buildButton(
    BuildContext context,
    WidgetRef ref,
    FollowState followState,
  ) {
    final isLoading = followState.isLoading;

    // ─── FOLLOWING button (outlined)
    if (followState.isFollowing) {
      return OutlinedButton(
        onPressed: isLoading
            ? null
            : () => _handleToggle(context, ref, followState),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: compact
              ? const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6)
              : const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
          minimumSize: compact ? Size.zero : const Size(88, 36),
          tapTargetSize: compact
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
        ),
        child: isLoading
            ? _loadingIndicator(AppColors.textPrimary)
            : Text(
                'Following',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      );
    }

    // ─── REQUESTED button (outlined, lighter)
    if (followState.isPending) {
      return OutlinedButton(
        onPressed: isLoading
            ? null
            : () => _handleToggle(context, ref, followState),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: compact
              ? const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6)
              : const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
          minimumSize: compact ? Size.zero : const Size(88, 36),
          tapTargetSize: compact
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
        ),
        child: isLoading
            ? _loadingIndicator(AppColors.textSecondary)
            : Text(
                'Requested',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      );
    }

    // ─── FOLLOW button (filled blue)
    return ElevatedButton(
      onPressed: isLoading
          ? null
          : () => _handleToggle(context, ref, followState),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: compact
            ? const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6)
            : const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
        minimumSize: compact ? Size.zero : const Size(88, 36),
        tapTargetSize: compact
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
      ),
      child: isLoading
          ? _loadingIndicator(Colors.white)
          : Text(
              'Follow',
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w600,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
            ),
            backgroundColor: AppColors.secondary,
            duration: const Duration(seconds: 2),
          ),
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
}
