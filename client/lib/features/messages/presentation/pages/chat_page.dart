// lib/features/messages/presentation/pages/chat_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../providers/message_provider.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/message_model.dart';
import '../../../../core/socket/socket_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  final ConversationModel? conversation; // Passed from inbox

  const ChatPage({super.key, required this.conversationId, this.conversation});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load older messages when scrolled to bottom
    // (list is reversed so bottom = older messages)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(chatProvider(widget.conversationId).notifier).loadMore();
    }
  }

  ConversationModel? _conversationFromInbox(String conversationId) {
    final conversations = ref.watch(inboxProvider).conversations;
    for (final conversation in conversations) {
      if (conversation.id == conversationId) {
        return conversation;
      }
    }
    return null;
  }

  // ─── SEND MESSAGE ──────────────────────────────────────────
  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    _messageFocus.requestFocus();

    ref.read(chatProvider(widget.conversationId).notifier).onTextChanged('');

    final success = await ref
        .read(chatProvider(widget.conversationId).notifier)
        .sendMessage(content);

    if (success) {
      // Update inbox last message
      ref
          .read(inboxProvider.notifier)
          .updateConversationLastMessage(widget.conversationId, content);

      // Scroll to top (newest message)
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  // ─── LONG PRESS OPTIONS ───────────────────────────────────
  void _showMessageOptions(
    BuildContext context,
    MessageModel message,
    String currentUserId,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // Reply option
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(chatProvider(widget.conversationId).notifier)
                    .setReplyingTo(message);
                _messageFocus.requestFocus();
              },
            ),

            // Copy option (for text messages)
            if (message.isText && !message.isDeleted)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: message.content ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),

            // Unsend (own messages only)
            if (message.sender?.id == currentUserId && !message.isDeleted)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.secondary,
                ),
                title: const Text(
                  'Unsend',
                  style: TextStyle(color: AppColors.secondary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(chatProvider(widget.conversationId).notifier)
                      .unsendMessage(message.id);
                },
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.conversationId));
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?.id ?? '';

    // Get conversation info (from extra or from state)
    final conv =
        widget.conversation ?? _conversationFromInbox(widget.conversationId);
    final displayName =
        conv?.displayName ?? conv?.otherUser?.username ?? 'Chat';
    final displayAvatarUrl = conv?.displayAvatarUrl;

    return Scaffold(
      backgroundColor: AppColors.white,

      // ─── APP BAR ────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
        title: GestureDetector(
          onTap: () {
            // Navigate to profile
            if (conv?.otherUser != null) {
              context.go('/profile/${conv!.otherUser!.username}');
            }
          },
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.border,
                    ),
                    child: ClipOval(
                      child: displayAvatarUrl != null
                          ? CachedNetworkImage(
                              imageUrl: displayAvatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) =>
                                  _defaultAvatar(displayName),
                            )
                          : _defaultAvatar(displayName),
                    ),
                  ),
                  if (conv?.otherUser != null)
                    Consumer(
                      builder: (context, ref, _) {
                        final isOnline = ref
                            .watch(socketProvider)
                            .isUserOnline(conv!.otherUser!.id);
                        if (!isOnline) {
                          return const SizedBox.shrink();
                        }

                        return Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),

              const SizedBox(width: 10),

              Flexible(
                child: Consumer(
                  builder: (context, ref, _) {
                    final isOnline = conv?.otherUser != null
                        ? ref
                              .watch(socketProvider)
                              .isUserOnline(conv!.otherUser!.id)
                        : false;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (isOnline)
                          const Text(
                            'Active now',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.phone_outlined,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.videocam_outlined,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),

      // ─── BODY ───────────────────────────────────────────
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: chatState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : chatState.messages.isEmpty
                ? const _EmptyChat()
                : _buildMessagesList(chatState, currentUserId, context),
          ),

          if (chatState.isOtherUserTyping)
            _TypingIndicator(conversationId: widget.conversationId),

          // Reply indicator
          if (chatState.replyingTo != null)
            _buildReplyIndicator(chatState.replyingTo!),

          // Message input
          _buildMessageInput(chatState),
        ],
      ),
    );
  }

  // ─── MESSAGES LIST ────────────────────────────────────────
  Widget _buildMessagesList(
    ChatState chatState,
    String currentUserId,
    BuildContext context,
  ) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Show newest at bottom
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: chatState.messages.length + (chatState.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading more indicator at bottom (older messages)
        if (index == chatState.messages.length) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          );
        }

        final message = chatState.messages[index];
        final isOwnMessage = message.sender?.id == currentUserId;
        final nextMessage = index < chatState.messages.length - 1
            ? chatState.messages[index + 1]
            : null;
        final prevMessage = index > 0 ? chatState.messages[index - 1] : null;

        // Show avatar only for first message in a group
        final showAvatar =
            !isOwnMessage &&
            (prevMessage == null ||
                prevMessage.sender?.id != message.sender?.id);

        // Show timestamp between messages if > 30 min apart
        final showTimestamp =
            nextMessage == null ||
            (message.createdAt != null &&
                nextMessage.createdAt != null &&
                message.createdAt!
                        .difference(nextMessage.createdAt!)
                        .inMinutes
                        .abs() >
                    30);

        return Column(
          children: [
            if (showTimestamp && message.createdAt != null)
              _TimestampDivider(dateTime: message.createdAt!),

            _MessageBubble(
              message: message,
              isOwnMessage: isOwnMessage,
              showAvatar: showAvatar,
              onLongPress: () =>
                  _showMessageOptions(context, message, currentUserId),
              onReply: () {
                ref
                    .read(chatProvider(widget.conversationId).notifier)
                    .setReplyingTo(message);
                _messageFocus.requestFocus();
              },
            ),
          ],
        );
      },
    );
  }

  // ─── REPLY INDICATOR ─────────────────────────────────────
  Widget _buildReplyIndicator(MessageModel replyingTo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.background,
      child: Row(
        children: [
          // Colored bar
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),

          // Reply preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reply to ${replyingTo.sender?.username ?? 'message'}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  replyingTo.displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Cancel reply
          GestureDetector(
            onTap: () => ref
                .read(chatProvider(widget.conversationId).notifier)
                .setReplyingTo(null),
            child: const Icon(
              Icons.close,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── MESSAGE INPUT ────────────────────────────────────────
  Widget _buildMessageInput(ChatState chatState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Camera icon
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.textPrimary,
              ),
            ),

            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocus,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (text) {
                          setState(() {});
                          ref
                              .read(
                                chatProvider(widget.conversationId).notifier,
                              )
                              .onTextChanged(text);
                        },
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    // Emoji
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send / Like button
            if (_messageController.text.trim().isEmpty)
              // Like button when no text
              GestureDetector(
                onTap: () async {
                  await ref
                      .read(chatProvider(widget.conversationId).notifier)
                      .sendMessage('❤️');
                },
                child: const Text('❤️', style: TextStyle(fontSize: 28)),
              )
            else
              // Send button when has text
              GestureDetector(
                onTap: chatState.isSending ? null : _sendMessage,
                child: chatState.isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Text(
                        'Send',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar(String name) {
    return Container(
      color: AppColors.border,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── MESSAGE BUBBLE ──────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isOwnMessage;
  final bool showAvatar;
  final VoidCallback onLongPress;
  final VoidCallback onReply;

  const _MessageBubble({
    required this.message,
    required this.isOwnMessage,
    required this.showAvatar,
    required this.onLongPress,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isOwnMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user avatar (left side)
          if (!isOwnMessage)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.border,
              ),
              child: showAvatar
                  ? ClipOval(
                      child: message.sender?.profilePicUrl != null
                          ? CachedNetworkImage(
                              imageUrl: message.sender!.profilePicUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: AppColors.border,
                              child: Center(
                                child: Text(
                                  message.sender?.username.isNotEmpty == true
                                      ? message.sender!.username[0]
                                            .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                    )
                  : null,
            )
          else if (!isOwnMessage)
            const SizedBox(width: 36),

          // Message content
          GestureDetector(
            onLongPress: message.isDeleted ? null : onLongPress,
            child: Column(
              crossAxisAlignment: isOwnMessage
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Reply preview
                if (message.repliedTo != null)
                  _ReplyPreview(
                    repliedTo: message.repliedTo!,
                    isOwnMessage: isOwnMessage,
                  ),

                // Message bubble
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: message.isDeleted
                        ? AppColors.background
                        : isOwnMessage
                        ? AppColors.primary
                        : AppColors.background,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isOwnMessage ? 18 : 4),
                      bottomRight: Radius.circular(isOwnMessage ? 4 : 18),
                    ),
                    border: message.isDeleted
                        ? Border.all(color: AppColors.border)
                        : null,
                  ),
                  child: Text(
                    message.displayText,
                    style: TextStyle(
                      color: message.isDeleted
                          ? AppColors.textSecondary
                          : isOwnMessage
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontSize: 14,
                      fontStyle: message.isDeleted
                          ? FontStyle.italic
                          : FontStyle.normal,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Own message: no avatar needed
          if (isOwnMessage) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─── REPLY PREVIEW (inside bubble) ──────────────────────────
class _ReplyPreview extends StatelessWidget {
  final RepliedToModel repliedTo;
  final bool isOwnMessage;

  const _ReplyPreview({required this.repliedTo, required this.isOwnMessage});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOwnMessage
            ? Colors.white.withValues(alpha: 0.2)
            : AppColors.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isOwnMessage ? Colors.white54 : AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Text(
        repliedTo.displayContent,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isOwnMessage ? Colors.white70 : AppColors.textSecondary,
          fontSize: 12,
          fontStyle: repliedTo.isDeleted ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}

// ─── TIMESTAMP DIVIDER ───────────────────────────────────────
class _TimestampDivider extends StatelessWidget {
  final DateTime dateTime;

  const _TimestampDivider({required this.dateTime});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          timeago.format(dateTime),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}

// ─── EMPTY CHAT ──────────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: AppColors.border),
          SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Say hi! 👋', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── TYPING INDICATOR WIDGET ─────────────────────────────────
class _TypingIndicator extends ConsumerWidget {
  final String conversationId;

  const _TypingIndicator({required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider(conversationId));
    if (!chatState.isOtherUserTyping) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

// ─── ANIMATED TYPING DOTS ────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _animations = _controllers.map((c) {
      return Tween<double>(
        begin: 0,
        end: -6,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut));
    }).toList();

    // Stagger the animations
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (_, _) => Transform.translate(
            offset: Offset(0, _animations[i].value),
            child: Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: const BoxDecoration(
                color: AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
