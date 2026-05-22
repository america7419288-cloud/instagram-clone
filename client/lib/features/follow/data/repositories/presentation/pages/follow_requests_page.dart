// lib/features/follow/presentation/pages/follow_requests_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../../core/router/navigation_extensions.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../shared/widgets/app_snackbar.dart';
import '../../../../../../shared/widgets/user_story_avatar.dart';
import '../providers/follow_provider.dart';

class FollowRequestsPage extends ConsumerWidget {
  const FollowRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(followRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Follow Requests',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : state.requests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_add_disabled,
                    size: 60,
                    color: AppColors.border,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Follow Requests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'When someone requests to follow you,\nyou\'ll see them here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: state.requests.length,
              itemBuilder: (context, index) {
                final request = state.requests[index];
                final requester =
                    request['requester'] as Map<String, dynamic>? ?? {};

                return _FollowRequestItem(
                  requester: requester,
                  requestedAt: request['requested_at'] as String?,
                  onAccept: () async {
                    await ref
                        .read(followRequestsProvider.notifier)
                        .acceptRequest(requester['id'] ?? '');
                    if (context.mounted) {
                      AppSnackbar.success(
                        context,
                        'You accepted @${requester['username']}\'s request.',
                      );
                    }
                  },
                  onDecline: () async {
                    await ref
                        .read(followRequestsProvider.notifier)
                        .rejectRequest(requester['id'] ?? '');
                  },
                );
              },
            ),
    );
  }
}

class _FollowRequestItem extends StatefulWidget {
  final Map<String, dynamic> requester;
  final String? requestedAt;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  const _FollowRequestItem({
    required this.requester,
    this.requestedAt,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_FollowRequestItem> createState() => _FollowRequestItemState();
}

class _FollowRequestItemState extends State<_FollowRequestItem> {
  bool _isLoading = false;
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    if (_handled) return const SizedBox.shrink();

    final username = widget.requester['username'] as String? ?? '';
    final fullName = widget.requester['full_name'] as String? ?? '';
    final profilePicUrl = widget.requester['profile_pic_url'] as String?;
    final isVerified = widget.requester['is_verified'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => context.pushIfNotCurrent('/profile/$username'),
            child: UserStoryAvatar(
              userId: widget.requester['id'] as String? ?? '',
              profilePicUrl: profilePicUrl,
              username: username,
              size: 52,
              showPresence: false,
              isClickable: true,
            ),
          ),

          const SizedBox(width: 12),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
                if (fullName.isNotEmpty)
                  Text(
                    fullName,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),

          // Accept / Decline buttons
          if (_isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Confirm button
                ElevatedButton(
                  onPressed: () => _handleAccept(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),

                const SizedBox(width: 8),

                // Delete button
                OutlinedButton(
                  onPressed: () => _handleDecline(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _handleAccept() async {
    setState(() => _isLoading = true);
    try {
      await widget.onAccept();
      setState(() => _handled = true);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDecline() async {
    setState(() => _isLoading = true);
    try {
      await widget.onDecline();
      setState(() => _handled = true);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
