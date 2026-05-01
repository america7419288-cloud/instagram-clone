// lib/features/notifications/presentation/pages/notifications_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../data/models/notification_model.dart';
import 'providers/notification_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() =>
      _NotificationsPageState();
}

class _NotificationsPageState
    extends ConsumerState<NotificationsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: AppColors.white,

      // ─── APP BAR ──────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Activity',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          // Mark all read button
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref
                  .read(notificationProvider.notifier)
                  .markAllAsRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),

      // ─── BODY ─────────────────────────────────────────────
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(notificationProvider.notifier).refresh(),
        color: AppColors.primary,
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(NotificationState state) {
    // Loading
    if (state.isLoading) {
      return const _NotificationsSkeleton();
    }

    // Error
    if (state.errorMessage != null &&
        state.notifications.isEmpty) {
      return _ErrorState(
        message: state.errorMessage!,
        onRetry: () =>
            ref.read(notificationProvider.notifier).refresh(),
      );
    }

    // Empty
    if (state.notifications.isEmpty) {
      return const _EmptyNotifications();
    }

    // Grouped list
    final groups = state.groupedNotifications;

    return ListView.builder(
      controller: _scrollController,
      itemCount: groups.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading more indicator
        if (index == groups.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final group = groups[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                group.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            // Notifications in group
            ...group.notifications.map(
              (notification) => _NotificationItem(
                notification: notification,
                onTap: () => _handleNotificationTap(notification),
                onDelete: () => ref
                    .read(notificationProvider.notifier)
                    .deleteNotification(notification.id),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── HANDLE TAP ───────────────────────────────────────────
  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read
    if (!notification.isRead) {
      ref
          .read(notificationProvider.notifier)
          .markAsRead(notification.id);
    }

    // Navigate based on notification type
    if (notification.referencePostId != null) {
      context.push('/post/${notification.referencePostId}');
    } else if (notification.sender != null &&
        (notification.isFollow ||
            notification.isFollowRequest ||
            notification.isFollowAccept)) {
      context.push('/profile/${notification.sender!.username}');
    }
  }
}

// ─── NOTIFICATION ITEM ──────────────────────────────────────
class _NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.secondary,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 24,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: notification.isRead
              ? Colors.transparent
              : AppColors.primary.withOpacity(0.04),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─── UNREAD INDICATOR ──────────────────────
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: notification.isRead
                      ? Colors.transparent
                      : AppColors.primary,
                ),
              ),

              // ─── SENDER AVATAR ─────────────────────────
              _buildAvatar(),

              const SizedBox(width: 12),

              // ─── MESSAGE + TIME ────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message with bold username
                    _buildMessage(),

                    const SizedBox(height: 4),

                    // Time ago
                    Text(
                      notification.createdAt != null
                          ? timeago.format(notification.createdAt!)
                          : '',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ─── RIGHT SIDE ────────────────────────────
              _buildRightSide(context),
            ],
          ),
        ),
      ),
    );
  }

  // ─── AVATAR ───────────────────────────────────────────────
  Widget _buildAvatar() {
    final sender = notification.sender;

    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.border,
          ),
          child: ClipOval(
            child: sender?.profilePicUrl != null
                ? CachedNetworkImage(
                    imageUrl: sender!.profilePicUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        _defaultAvatar(sender.username),
                  )
                : _defaultAvatar(sender?.username ?? '?'),
          ),
        ),

        // Notification type icon (bottom right of avatar)
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _typeColor(),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(
              _typeIcon(),
              color: Colors.white,
              size: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar(String username) {
    return Container(
      color: AppColors.border,
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─── MESSAGE TEXT ─────────────────────────────────────────
  Widget _buildMessage() {
    final username = notification.sender?.username ?? '';

    // Split message: "username action text"
    // Make username bold, rest normal
    if (notification.message.startsWith(username)) {
      final rest = notification.message
          .substring(username.length);
      return RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.3,
          ),
          children: [
            TextSpan(
              text: username,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: rest),
          ],
        ),
      );
    }

    return Text(
      notification.message,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
    );
  }

  // ─── RIGHT SIDE ───────────────────────────────────────────
  Widget _buildRightSide(BuildContext context) {
    // Post thumbnail
    if (notification.postThumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: notification.postThumbnail!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            width: 44,
            height: 44,
            color: AppColors.border,
            child: const Icon(
              Icons.image_outlined,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    // Follow button (for follow/follow_request types)
    if (notification.showFollowButton) {
      return _FollowButton(
        notificationId: notification.id,
        isFollowRequest: notification.isFollowRequest,
      );
    }

    return const SizedBox.shrink();
  }

  // ─── TYPE ICON ────────────────────────────────────────────
  IconData _typeIcon() {
    switch (notification.type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
      case 'reply':
        return Icons.chat_bubble;
      case 'follow':
      case 'follow_request':
      case 'follow_accept':
        return Icons.person;
      case 'mention_post':
      case 'mention_comment':
        return Icons.alternate_email;
      case 'comment_like':
        return Icons.favorite;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor() {
    switch (notification.type) {
      case 'like':
      case 'comment_like':
        return AppColors.secondary;
      case 'comment':
      case 'reply':
        return const Color(0xFF0095F6);
      case 'follow':
      case 'follow_request':
      case 'follow_accept':
        return const Color(0xFF833AB4);
      case 'mention_post':
      case 'mention_comment':
        return const Color(0xFFFCB045);
      default:
        return AppColors.textSecondary;
    }
  }
}

// ─── FOLLOW BUTTON ──────────────────────────────────────────
class _FollowButton extends ConsumerStatefulWidget {
  final String notificationId;
  final bool isFollowRequest;

  const _FollowButton({
    required this.notificationId,
    required this.isFollowRequest,
  });

  @override
  ConsumerState<_FollowButton> createState() =>
      _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _isFollowing = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (_isFollowing) {
      return OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Following',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: _isLoading ? null : _handleFollow,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              widget.isFollowRequest ? 'Confirm' : 'Follow',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Future<void> _handleFollow() async {
    setState(() => _isLoading = true);

    // TODO: Call follow API
    // For now simulate success
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isFollowing = true;
      });
    }
  }
}

// ─── SKELETON LOADING ───────────────────────────────────────
class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.border,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 120,
                    decoration: BoxDecoration(
                      color: AppColors.border.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EMPTY STATE ────────────────────────────────────────────
class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textPrimary,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 40,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Activity On Your Posts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'When someone likes or comments on one of your posts, you\'ll see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ERROR STATE ────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
