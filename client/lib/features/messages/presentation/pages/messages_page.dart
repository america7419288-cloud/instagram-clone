// lib/features/messages/presentation/pages/messages_page.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/verified_badge.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/user_story_avatar.dart';
import '../../../chat/data/models/conversation.dart';
import '../../../chat/presentation/providers/chat_notifiers.dart';
import '../../../chat/presentation/providers/presence_provider.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inboxState = ref.watch(inboxProvider);
    final currentUser = ref.watch(currentUserProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: bgColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 0.33,
          ),
        ),
        leading: Navigator.canPop(context)
            ? BouncyTap(
                onTap: () => context.pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Icon(
                    LucideIcons.chevron_left,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
              )
            : null,
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentUser?.username ?? 'Messages',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17,
                fontFamily: 'SF Pro Display',
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevron_down,
              color: AppColors.textPrimary,
              size: 16,
            ),
          ],
        ),
        trailing: BouncyTap(
          onTap: () => context.push(AppRoutes.newMessage),
          child: Icon(
            LucideIcons.square_pen,
            color: AppColors.textPrimary,
            size: 24,
          ),
        ),
      ),
      child: Material(
        color: isDark ? Colors.black : Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: BouncyTap(
                  onTap: () {
                    context.push('/messages/search');
                  },
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.shimmerBase,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(
                          LucideIcons.search,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Search',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Primary/General tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        padding: EdgeInsets.zero,
                        indicatorColor: AppColors.textPrimary,
                        indicatorWeight: 1,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelColor: AppColors.textPrimary,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        tabs: const [
                          Tab(text: 'Primary'),
                          Tab(text: 'General'),
                        ],
                        dividerColor: Colors.transparent,
                      ),
                    ),
                    BouncyTap(
                      onTap: () {},
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Requests',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Content
              Expanded(
                child: inboxState.isLoading
                    ? const _InboxSkeleton()
                    : inboxState.error != null &&
                          inboxState.conversations.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          ErrorView(
                            message: inboxState.error!,
                            onRetry: () => ref
                                .read(inboxProvider.notifier)
                                .loadConversations(),
                          ),
                        ],
                      )
                    : inboxState.conversations.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 60),
                          EmptyState.messages(),
                        ],
                      )
                    : _buildConversationList(
                        context,
                        inboxState.conversations,
                        currentUser?.id ?? '',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList(
    BuildContext context,
    List<Conversation> conversations,
    String currentUserId,
  ) {
    // Tell the presence provider which users to track via socket
    final userIdsToTrack = conversations
        .map((c) => c.otherUser?.id)
        .whereType<String>()
        .toList();
    if (userIdsToTrack.isNotEmpty) {
      ref.read(presenceProvider.notifier).trackUsers(userIdsToTrack);
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conv = conversations[index];
        return _ConversationTile(
          conversation: conv,
          currentUserId: currentUserId,
          onTap: () {
            if (conv.id.isEmpty) return;
            context.push(
              '/chat/${conv.id}',
              extra: <String, dynamic>{
                'username': conv.name ?? 'User',
                'avatarUrl': conv.avatarUrl,
                'isVerified': conv.otherUser?.isVerified ?? false,
              },
            );
          },
          onDismissed: () {
            ref.read(inboxProvider.notifier).deleteConversation(conv.id);
          },
        );
      },
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
    required this.onDismissed,
  });

  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  // ── Build the last-message preview subtitle ──────────────────
  // Mirrors Instagram: "You: hey" vs just "hey" for inbound messages.
  String _buildLastMessagePreview(String currentUserId) {
    final msg = conversation.lastMessage;
    if (msg == null) return 'Start a conversation';

    final isOwn = msg.senderId == currentUserId;
    final prefix = isOwn ? 'You: ' : '';

    // Deleted message
    if (msg.isDeleted) {
      return isOwn ? 'You unsent a message' : 'Message unsent';
    }

    // Media / special types
    switch (msg.messageType) {
      case 'image':
        return '${prefix}Sent a photo';
      case 'video':
        return '${prefix}Sent a video';
      case 'like':
        return isOwn ? 'You sent \u2764\ufe0f' : '\u2764\ufe0f';
      case 'reel':
        return '${prefix}Shared a reel';
      case 'story':
        return '${prefix}Replied to a story';
      case 'post':
        return '${prefix}Shared a post';
      default:
        final text = msg.content.trim();
        return text.isEmpty ? '${prefix}...' : '$prefix$text';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(
      presenceProvider.select(
        (s) => s.onlineUsers[conversation.otherUser?.id ?? ''] ?? false,
      ),
    );
    final timeText = timeago.format(conversation.updatedAt, locale: 'en_short');
    final hasUnread = conversation.unreadCount > 0;

    return Dismissible(
      key: Key(conversation.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Delete Chat?'),
            content: const Text('Once deleted, this conversation will be removed from your inbox.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context, false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('Delete'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        onDismissed();
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.grey[300],
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.pin, color: Colors.white),
                const SizedBox(height: 4),
                const Text(
                  'Pin',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.eclipse, color: Colors.white),
                const SizedBox(height: 4),
                const Text(
                  'More',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Container(
              color: Colors.red,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.trash_2, color: Colors.white),
                  const SizedBox(height: 4),
                  const Text(
                    'Delete',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      child: BouncyTap(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildAvatar(isOnline, context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  conversation.isGroup
                                      ? (conversation.name ?? 'Group')
                                      : (conversation.otherUser?.username ?? 'Chat'),
                                  style: TextStyle(
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'SF Pro Text',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (conversation.otherUser?.isVerified == true) ...[
                                const SizedBox(width: 4),
                                const VerifiedBadge(size: 13),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontFamily: 'SF Pro Text',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _buildLastMessagePreview(currentUserId),
                            style: TextStyle(
                              fontSize: 13,
                              color: hasUnread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontFamily: 'SF Pro Text',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              BouncyTap(
                onTap: () {
                  // TODO: Open camera
                },
                child: Icon(
                  LucideIcons.camera,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isOnline, BuildContext context) {
    if (conversation.isGroup) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withValues(alpha: 0.2),
          image: conversation.avatarUrl != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(conversation.avatarUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: conversation.avatarUrl == null
            ? Icon(LucideIcons.users, color: AppColors.textPrimary)
            : null,
      );
    }
    return UserStoryAvatar(
      userId: conversation.otherUser?.id ?? '',
      profilePicUrl: conversation.otherUser?.profilePicUrl,
      username: conversation.otherUser?.username,
      size: 56,
      showPresence: true,
      isClickable: true,
    );
  }
}

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.border,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 120, color: AppColors.border),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: 200,
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
