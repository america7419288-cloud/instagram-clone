// lib/features/notifications/presentation/pages/notifications_page.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/router/navigation_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/user_story_avatar.dart';
import '../../data/models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── Navigation Bar ─────────────────────────────────
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            largeTitle: const Text(
              'Notifications',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontWeight: FontWeight.bold,
              ),
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withValues(alpha: 0.3),
                width: 0.33,
              ),
            ),
            backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white).withValues(alpha: 0.9),
          ),

          // ─── Refresh Control ──────────────────────────────
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await ref.read(notificationProvider.notifier).refresh();
            },
          ),

          // ─── Follow Requests Section ──────────────────────
          if (state.notifications.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildFollowRequestsHeader(),
            ),

          // ─── Notifications List ───────────────────────────
          if (state.notifications.isEmpty && !state.isLoading)
            const SliverFillRemaining(
              child: Center(child: EmptyState.notifications()),
            )
          else
            _buildNotificationsList(state),

          // ─── Loading More ─────────────────────────────────
          if (state.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoActivityIndicator(),
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildFollowRequestsHeader() {
    return Column(
      children: [
        BouncyTap(
          onTap: () => context.pushIfNotCurrent('/follow-requests'),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.border,
                  child: Icon(LucideIcons.user_plus, color: AppColors.textPrimary),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            title: const Text(
              'Follow Requests',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'Approve or ignore requests',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: const Icon(LucideIcons.chevron_right, color: AppColors.border, size: 20),
          ),
        ),
        const Divider(height: 1, indent: 72),
      ],
    );
  }

  Widget _buildNotificationsList(NotificationState state) {
    final groups = state.groupedNotifications;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final group = groups[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              ...group.notifications.map(
                (notification) => _NotificationRow(
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
        childCount: groups.length,
      ),
    );
  }

  void _handleNotificationTap(NotificationModel notification) {
    if (!notification.isRead) {
      ref.read(notificationProvider.notifier).markAsRead(notification.id);
    }

    if (notification.referencePostId != null) {
      context.pushIfNotCurrent('/post/${notification.referencePostId}');
    } else if (notification.sender != null) {
      context.pushIfNotCurrent('/profile/${notification.sender!.username}');
    }
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(LucideIcons.trash_2, color: Colors.white),
      ),
      child: BouncyTap(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.transparent
                : AppColors.primary.withValues(alpha: 0.1),
          ),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContent(),
              ),
              const SizedBox(width: 12),
              _buildAction(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final sender = notification.sender;
    return UserStoryAvatar(
      userId: sender?.id ?? '',
      profilePicUrl: sender?.profilePicUrl,
      username: sender?.username,
      size: 44,
      showPresence: false,
      isClickable: true,
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: AppColors.border,
      child: const Icon(LucideIcons.user, color: Colors.white, size: 24),
    );
  }

  Widget _buildContent() {
    final username = notification.sender?.username ?? 'Someone';
    final message = notification.message;
    final timeStr = notification.createdAt != null
        ? ' ${timeago.format(notification.createdAt!, locale: 'en_short')}'
        : '';

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
          fontFamily: 'SF Pro Text',
        ),
        children: [
          TextSpan(
            text: username,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: ' $message'),
          TextSpan(
            text: timeStr,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    if (notification.postThumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: notification.postThumbnail!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
        ),
      );
    }

    if (notification.showFollowButton) {
      return _NotificationFollowButton(
        notificationId: notification.id,
        isFollowRequest: notification.isFollowRequest,
      );
    }

    return const SizedBox.shrink();
  }
}

class _NotificationFollowButton extends ConsumerStatefulWidget {
  const _NotificationFollowButton({
    required this.notificationId,
    required this.isFollowRequest,
  });

  final String notificationId;
  final bool isFollowRequest;

  @override
  ConsumerState<_NotificationFollowButton> createState() =>
      _NotificationFollowButtonState();
}

class _NotificationFollowButtonState
    extends ConsumerState<_NotificationFollowButton> {
  bool _isFollowing = false;

  @override
  Widget build(BuildContext context) {
    if (_isFollowing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Following',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      );
    }

    return BouncyTap(
      onTap: () {
        setState(() => _isFollowing = true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          widget.isFollowRequest ? 'Confirm' : 'Follow',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

