// lib/features/messages/presentation/pages/chat_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../providers/message_provider.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/message_model.dart';
import '../../../../core/socket/socket_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  final ConversationModel? conversation;

  const ChatPage({super.key, required this.conversationId, this.conversation});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _messageFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isTyping = _messageController.text.trim().isNotEmpty;
    if (isTyping != _isTyping) {
      setState(() => _isTyping = isTyping);
    }
  }

  void _onScroll() {
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    _messageFocus.requestFocus();

    final success = await ref
        .read(chatProvider(widget.conversationId).notifier)
        .sendMessage(content);

    if (success) {
      ref
          .read(inboxProvider.notifier)
          .updateConversationLastMessage(widget.conversationId, content);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.conversationId));
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?.id ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final conv =
        widget.conversation ?? _conversationFromInbox(widget.conversationId);
    final displayName =
        conv?.displayName ?? conv?.otherUser?.username ?? 'Chat';
    final displayAvatarUrl = conv?.displayAvatarUrl;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: _buildAppBar(context, displayName, displayAvatarUrl, conv),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _buildMessagesList(chatState, currentUserId, isDark),
          ),
          if (chatState.isOtherUserTyping)
            _TypingIndicator(isDark: isDark),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String title,
      String? avatarUrl, ConversationModel? conv) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: isDark ? Colors.black : Colors.white,
      elevation: 0.5,
      toolbarHeight: 44,
      leadingWidth: 40,
      titleSpacing: 0,
      leading: BouncyTap(
        onTap: () => context.pop(),
        child: const Icon(LucideIcons.chevron_left, size: 28),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            backgroundColor: AppColors.border,
            child: avatarUrl == null
                ? const Icon(LucideIcons.user,
                    size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Instagram-Sans',
                  ),
                ),
                _buildActiveStatus(conv),
              ],
            ),
          ),
        ],
      ),
      actions: [
        BouncyTap(
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(LucideIcons.phone, size: 24),
          ),
        ),
        BouncyTap(
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(LucideIcons.video, size: 24),
          ),
        ),
        BouncyTap(
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(LucideIcons.info, size: 24),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildActiveStatus(ConversationModel? conv) {
    if (conv?.otherUser == null) return const SizedBox.shrink();
    return Consumer(
      builder: (context, ref, _) {
        final isOnline =
            ref.watch(socketProvider).isUserOnline(conv!.otherUser!.id);
        return Text(
          isOnline ? 'Active now' : 'Active 5m ago', 
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'Instagram-Sans',
            color: isOnline ? const Color(0xFF4BB543) : AppColors.textSecondary,
          ),
        );
      },
    );
  }

  Widget _buildMessagesList(
      ChatState chatState, String currentUserId, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];
        final isOwn = message.sender?.id == currentUserId;
        final nextMsg = index > 0 ? chatState.messages[index - 1] : null;
        final prevMsg = index < chatState.messages.length - 1
            ? chatState.messages[index + 1]
            : null;

        final isLastInGroup =
            nextMsg == null || nextMsg.sender?.id != message.sender?.id;
        final isFirstInGroup =
            prevMsg == null || prevMsg.sender?.id != message.sender?.id;

        // Date separator logic
        Widget? dateSeparator;
        if (prevMsg == null ||
            _shouldShowDateSeparator(message.createdAt, prevMsg.createdAt)) {
          dateSeparator = _DateSeparator(date: message.createdAt);
        }

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            _iOSMessageBubble(
              message: message,
              isOwn: isOwn,
              isLastInGroup: isLastInGroup,
              isFirstInGroup: isFirstInGroup,
              isDark: isDark,
            ),
            if (isOwn && index == 0) // Show status only for the very last message
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Seen', // Mocked status
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _shouldShowDateSeparator(DateTime? current, DateTime? previous) {
    if (current == null || previous == null) return false;
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  Widget _iOSMessageBubble({
    required MessageModel message,
    required bool isOwn,
    required bool isLastInGroup,
    required bool isFirstInGroup,
    required bool isDark,
  }) {
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isOwn ? 18 : (isLastInGroup ? 4 : 18)),
      bottomRight: Radius.circular(isOwn ? (isLastInGroup ? 4 : 18) : 18),
    );

    return Container(
      margin: EdgeInsets.only(
        bottom: isLastInGroup ? 8 : 2,
        top: isFirstInGroup ? 4 : 0,
      ),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn) ...[
            SizedBox(
              width: 20,
              height: 20,
              child: isLastInGroup
                  ? CircleAvatar(
                      radius: 10,
                      backgroundImage: message.sender?.profilePicUrl != null
                          ? NetworkImage(message.sender!.profilePicUrl!)
                          : null,
                      backgroundColor: AppColors.border,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: isOwn
                    ? const LinearGradient(
                        colors: [AppColors.primary, Color(0xFFA033FF)],
                        begin: Alignment.bottomRight,
                        end: Alignment.topLeft,
                      )
                    : null,
                color: isOwn
                    ? null
                    : (isDark ? AppColors.darkShimmerBase : AppColors.shimmerBase),
              ),
              child: Text(
                message.content ?? '',
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Instagram-Sans',
                  color: isOwn
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
            top: BorderSide(
                color: isDark ? AppColors.darkShimmerBase : AppColors.border,
                width: 0.5)),
      ),
      child: Row(
        children: [
          // Camera button
          BouncyTap(
            onTap: () {
              // TODO: Open camera
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.camera,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          // Input pill
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: isDark
                        ? AppColors.darkShimmerBase
                        : AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocus,
                      maxLines: 5,
                      minLines: 1,
                      style: const TextStyle(fontSize: 15, fontFamily: 'Instagram-Sans'),
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const Icon(LucideIcons.smile, size: 24),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Right action
          _isTyping
              ? BouncyTap(
                  onTap: _sendMessage,
                  child: const Text(
                    'Send',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16),
                  ),
                )
              : Row(
                  children: [
                    BouncyTap(
                      onTap: () {},
                      child: const Icon(LucideIcons.mic, size: 24),
                    ),
                    const SizedBox(width: 16),
                    BouncyTap(
                      onTap: () {},
                      child: const Icon(LucideIcons.image, size: 24),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime? date;
  const _DateSeparator({this.date});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    String text;
    final now = DateTime.now();
    if (date!.year == now.year &&
        date!.month == now.month &&
        date!.day == now.day) {
      text = 'Today';
    } else if (date!.year == now.year &&
        date!.month == now.month &&
        date!.day == now.day - 1) {
      text = 'Yesterday';
    } else {
      text = DateFormat('MMMM d, yyyy').format(date!);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final bool isDark;
  const _TypingIndicator({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const SizedBox(width: 28), // Avatar space
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkShimmerBase : AppColors.shimmerBase,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const _BouncingDots(),
          ),
        ],
      ),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
        3,
        (i) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 300)));
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -4).animate(c))
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
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
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _animations[i].value),
            child: Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: const BoxDecoration(
                  color: AppColors.textSecondary, shape: BoxShape.circle),
            ),
          ),
        );
      }),
    );
  }
}

