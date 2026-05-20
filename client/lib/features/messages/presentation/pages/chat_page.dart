import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';

// Providers & Models
import '../../../chat/presentation/providers/chat_notifiers.dart';
import '../../../chat/presentation/providers/typing_provider.dart';
import '../../../chat/presentation/providers/presence_provider.dart';
import '../../../chat/data/models/conversation.dart';
import '../../../chat/data/models/message.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

// UI Components
import '../widgets/chat/chat_ui_constants.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/chat/message_bubbles.dart';
import '../widgets/chat/message_bubble_wrapper.dart';
import '../widgets/chat/chat_overlays.dart';
import '../widgets/chat/reaction_overlay.dart';
import '../widgets/chat/message_edit_dialog.dart';
import '../widgets/chat/disappearing_message_dialog.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  final Conversation? conversation;

  const ChatPage({super.key, required this.conversationId, this.conversation});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  Message? _replyingTo;
  bool _showScrollToBottom = false;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  // For Heart Burst
  final List<OverlayEntry> _heartOverlays = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    // Mark as read when entering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider(widget.conversationId).notifier).markAsRead();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _recordingTimer?.cancel();
    for (var overlay in _heartOverlays) {
      overlay.remove();
    }
    super.dispose();
  }

  void _scrollListener() {
    final offset = _scrollController.offset;
    final isVisible = offset > 200;
    if (isVisible != _showScrollToBottom) {
      setState(() => _showScrollToBottom = isVisible);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(0);
    }
  }

  void _handleSend(String text) {
    final replyId = _replyingTo?.id;
    setState(() => _replyingTo = null);

    ref
        .read(chatProvider(widget.conversationId).notifier)
        .sendMessage(text, replyToId: replyId);
    _scrollToBottom();
  }

  void _handleLike() {
    HapticFeedback.lightImpact();
    ref.read(chatProvider(widget.conversationId).notifier).sendLike();
    _scrollToBottom();
  }

  void _openProfile(String? username) {
    final cleanUsername = username?.trim();
    if (cleanUsername == null || cleanUsername.isEmpty) return;
    context.push('/profile/${Uri.encodeComponent(cleanUsername)}');
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _recordingDuration = Duration.zero;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration = DateTime.now().difference(_recordingStartTime!);
      });
    });
  }

  List<int> _int32ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  List<int> _int16ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
    ];
  }

  Future<String> _createSilentWavFile() async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.wav');
    final sampleRate = 16000;
    final channels = 1;
    final bitsPerSample = 16;
    final duration = 3;
    final dataSize = sampleRate * duration * channels * (bitsPerSample ~/ 8);
    final fileSize = 36 + dataSize;
    final builder = BytesBuilder();
    builder.add('RIFF'.codeUnits);
    builder.add(_int32ToBytes(fileSize));
    builder.add('WAVE'.codeUnits);
    builder.add('fmt '.codeUnits);
    builder.add(_int32ToBytes(16));
    builder.add(_int16ToBytes(1));
    builder.add(_int16ToBytes(channels));
    builder.add(_int32ToBytes(sampleRate));
    builder.add(_int32ToBytes(sampleRate * channels * (bitsPerSample ~/ 8)));
    builder.add(_int16ToBytes(channels * (bitsPerSample ~/ 8)));
    builder.add(_int16ToBytes(bitsPerSample));
    builder.add('data'.codeUnits);
    builder.add(_int32ToBytes(dataSize));
    builder.add(List<int>.filled(dataSize, 0));
    await file.writeAsBytes(builder.toBytes());
    return file.path;
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    setState(() => _isRecording = false);
    HapticFeedback.lightImpact();
    try {
      final wavPath = await _createSilentWavFile();
      ref
          .read(chatProvider(widget.conversationId).notifier)
          .sendMessage('', messageType: 'audio', mediaPath: wavPath);
    } catch (e) {
      debugPrint("Error generating silence WAV: $e");
    }
  }

  void _cancelRecording() {
    _recordingTimer?.cancel();
    setState(() => _isRecording = false);
    HapticFeedback.heavyImpact();
  }

  void _showHeartBurst(Offset offset) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx - 50,
        top: offset.dy - 50,
        child: Container(
          color: CupertinoColors.transparent,
          child: HeartBurstAnimation(
            onFinished: () {
              overlayEntry.remove();
              _heartOverlays.remove(overlayEntry);
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
    _heartOverlays.add(overlayEntry);
  }

  DisappearingDuration _mapDisappearingDuration(int? seconds) {
    if (seconds == null || seconds == 0) return DisappearingDuration.off;
    if (seconds <= 86400) return DisappearingDuration.twentyFourHours;
    if (seconds <= 604800) return DisappearingDuration.sevenDays;
    return DisappearingDuration.ninetyDays;
  }

  int? _mapDurationToSeconds(DisappearingDuration duration) {
    switch (duration) {
      case DisappearingDuration.off:
        return null;
      case DisappearingDuration.twentyFourHours:
        return 86400;
      case DisappearingDuration.sevenDays:
        return 604800;
      case DisappearingDuration.ninetyDays:
        return 7776000;
    }
  }

  void _showEditDialog(Message message) {
    MessageEditDialog.show(
      context: context,
      initialText: message.content,
      onSave: (newText) {
        ref
            .read(chatProvider(widget.conversationId).notifier)
            .editMessage(message.id, newText);
      },
    );
  }

  void _showDisappearingDialog() {
    final conversation = widget.conversation ??
        ref.watch(inboxProvider).conversations.firstWhere(
              (c) => c.id == widget.conversationId,
              orElse: () => Conversation(
                id: '',
                participants: const [],
                updatedAt: DateTime.now(),
              ),
            );

    DisappearingMessageDialog.show(
      context: context,
      currentDuration: _mapDisappearingDuration(conversation.disappearingDuration),
      onChanged: (duration) {
        final seconds = _mapDurationToSeconds(duration);
        ref
            .read(chatProvider(widget.conversationId).notifier)
            .setDisappearingMessages(seconds);
      },
    );
  }

  void _showChatOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showDisappearingDialog();
            },
            child: const Text('Disappearing Messages'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              final conversation = widget.conversation ??
                  ref.read(inboxProvider).conversations.firstWhere(
                        (c) => c.id == widget.conversationId,
                        orElse: () => Conversation(
                          id: '',
                          participants: const [],
                          updatedAt: DateTime.now(),
                        ),
                      );
              final otherUser = conversation.otherUser;
              _openProfile(otherUser?.username);
            },
            child: const Text('View Profile'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('Notifications'),
                  content: const Text('Notifications for this chat have been muted.'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('OK'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Mute Notifications'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              context.push('/messages/search');
            },
            child: const Text('Search in Conversation'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _handleCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        HapticFeedback.lightImpact();
        ref
            .read(chatProvider(widget.conversationId).notifier)
            .sendMessage('', messageType: 'image', mediaPath: photo.path);
      }
    } catch (e) {
      print('Error picking image from camera: $e');
    }
  }

  Future<void> _handleGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        HapticFeedback.lightImpact();
        for (var image in images) {
          ref
              .read(chatProvider(widget.conversationId).notifier)
              .sendMessage('', messageType: 'image', mediaPath: image.path);
        }
      }
    } catch (e) {
      print('Error picking images from gallery: $e');
    }
  }

  void _showMessageOptions(
    BuildContext context,
    Message message,
    bool isOwn,
    Offset offset,
    Size size,
  ) {
    // Use CupertinoActionSheet as a more reliable fallback
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(isOwn ? 'Your Message' : 'Message Options'),
        actions: [
          // Reactions
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(chatProvider(widget.conversationId).notifier)
                  .addReaction(message.id, '❤️');
            },
            child: const Text('❤️ React with Heart'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(chatProvider(widget.conversationId).notifier)
                  .addReaction(message.id, '😂');
            },
            child: const Text('😂 React with Laugh'),
          ),
          
          // Reply
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _replyingTo = message);
              _inputFocusNode.requestFocus();
            },
            child: const Text('Reply'),
          ),
          
          // Forward
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              context.push('/messages/forward', extra: message);
            },
            child: const Text('Forward'),
          ),
          
          // Copy (text only)
          if (message.messageType == 'text')
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.content));
                HapticFeedback.lightImpact();
              },
              child: const Text('Copy'),
            ),
          
          // Edit (own text messages only)
          if (message.messageType == 'text' && isOwn)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showEditDialog(message);
              },
              child: const Text('Edit'),
            ),
          
          // Save
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              HapticFeedback.lightImpact();
              // TODO: Implement save functionality
            },
            child: const Text('Save'),
          ),
          
          // Unsend (own messages only)
          if (isOwn)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                ref
                    .read(chatProvider(widget.conversationId).notifier)
                    .deleteMessage(message.id);
              },
              child: const Text('Unsend'),
            ),
          
          // Report
          if (!isOwn)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                // TODO: Implement report functionality
              },
              child: const Text('Report'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  String _formatDateDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) return "Today";
    if (dateToCheck == yesterday) return "Yesterday";

    if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    }

    return DateFormat('d MMMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.conversationId));
    final typingState = ref.watch(typingProvider(widget.conversationId));
    final currentUser = ref.watch(currentUserProvider);
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    final conversation =
        widget.conversation ??
        ref
            .watch(inboxProvider)
            .conversations
            .firstWhere(
              (c) => c.id == widget.conversationId,
              orElse: () => Conversation(
                id: '',
                participants: const [],
                updatedAt: DateTime.now(),
              ),
            );

    final otherUser = conversation.otherUser;
    final isOnline =
        otherUser != null &&
        ref.watch(presenceProvider.notifier).isUserOnline(otherUser.id);

    String statusText = '';
    if (typingState.typingUserIds.isNotEmpty) {
      statusText = 'Typing...';
    } else if (isOnline) {
      statusText = 'Active now';
    } else {
      statusText = 'Offline';
    }

    return CupertinoPageScaffold(
      backgroundColor: isDark
          ? ChatUIConstants.bgDark
          : ChatUIConstants.bgLight,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ChatAppBar(
              username: otherUser?.username ?? 'Chat',
              avatarUrl: otherUser?.profilePicUrl,
              statusText: statusText,
              isOnline: isOnline,
              isVerified: otherUser?.isVerified ?? false,
              hasStory: true,
              onProfileTap: () => _openProfile(otherUser?.username),
              onMoreTap: _showChatOptions,
            ),

            Expanded(
              child: Stack(
                children: [
                  _buildMessageList(chatState, currentUser?.id ?? ''),

                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: ScrollToBottomFAB(
                      isVisible: _showScrollToBottom,
                      onTap: () => _scrollToBottom(),
                      unreadCount: 0, // Could be linked to unread state
                    ),
                  ),
                ],
              ),
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: typingState.isTyping
                  ? TypingIndicator(
                      key: const ValueKey('typing'),
                      avatarUrl: otherUser?.profilePicUrl,
                    )
                  : const SizedBox.shrink(key: ValueKey('no_typing')),
            ),

            if (_replyingTo != null)
              ReplyPreviewBar(
                username: _replyingTo!.sender?.username ?? 'user',
                text: _replyingTo!.content,
                imageUrl: _replyingTo!.mediaUrl,
                onCancel: () => setState(() => _replyingTo = null),
              ),

            ChatInputBar(
              onSend: _handleSend,
              onChanged: (text) => ref
                  .read(typingProvider(widget.conversationId).notifier)
                  .onTextChanged(text),
              onLike: _handleLike,
              onCameraTap: _handleCamera,
              onGalleryTap: _handleGallery,
              onMicStart: _startRecording,
              onMicStop: _stopRecording,
              onMicCancel: _cancelRecording,
              isRecording: _isRecording,
              recordingDuration: _recordingDuration,
              focusNode: _inputFocusNode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatState state, String currentUserId) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (state.messages.isEmpty) {
      return const _EmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      reverse:
          true, // Instagram messages are usually reversed in Flutter for easier bottom-loading
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: state.messages.length + (state.messages.isEmpty ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == state.messages.length) {
          // This would be the "top" of the list (earliest message)
          return const SizedBox(height: 20);
        }

        final message = state.messages[index];
        final isOwn = currentUserId.isNotEmpty && message.senderId == currentUserId;

        final nextMsg = index > 0 ? state.messages[index - 1] : null;
        final prevMsg = index < state.messages.length - 1
            ? state.messages[index + 1]
            : null;

        final isLastInGroup =
            nextMsg == null || nextMsg.senderId != message.senderId;
        final isFirstInGroup =
            prevMsg == null || prevMsg.senderId != message.senderId;

        // Date divider
        bool showDateDivider = false;
        if (prevMsg == null) {
          showDateDivider = true;
        } else {
          final diff = message.createdAt
              .difference(prevMsg.createdAt)
              .inMinutes;
          if (diff > 30 || message.createdAt.day != prevMsg.createdAt.day) {
            showDateDivider = true;
          }
        }

        return TweenAnimationBuilder<double>(
          key: ValueKey(message.id),
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 180 + (index % 4) * 28),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 10),
                child: child,
              ),
            );
          },
          child: Column(
            children: [
              if (showDateDivider)
                _DateDivider(text: _formatDateDivider(message.createdAt)),
              MessageBubbleWrapper(
                isSent: isOwn,
                isFirstInGroup: isFirstInGroup,
                isLastInGroup: isLastInGroup,
                senderAvatar: message.sender?.profilePicUrl,
                onReply: () {
                  setState(() => _replyingTo = message);
                  _inputFocusNode.requestFocus();
                },
                onDoubleTap: () {
                  _handleLike();
                  final size = MediaQuery.of(context).size;
                  _showHeartBurst(Offset(size.width / 2, size.height / 2));
                },
                onLongPress: () {
                  HapticFeedback.heavyImpact();
                  
                  // Get the render box for positioning
                  try {
                    final RenderBox? renderBox =
                        context.findRenderObject() as RenderBox?;
                    
                    if (renderBox != null && renderBox.hasSize) {
                      final offset = renderBox.localToGlobal(Offset.zero);
                      _showMessageOptions(
                        context,
                        message,
                        isOwn,
                        offset,
                        renderBox.size,
                      );
                    } else {
                      // Fallback: show at center of screen
                      final size = MediaQuery.of(context).size;
                      _showMessageOptions(
                        context,
                        message,
                        isOwn,
                        Offset(size.width / 2, size.height / 2),
                        const Size(200, 50),
                      );
                    }
                  } catch (e) {
                    // Fallback: show at center of screen
                    final size = MediaQuery.of(context).size;
                    _showMessageOptions(
                      context,
                      message,
                      isOwn,
                      Offset(size.width / 2, size.height / 2),
                      const Size(200, 50),
                    );
                  }
                },
                statusRow: isOwn && isLastInGroup
                    ? StatusRow(
                        status: message.isRead
                            ? 'seen'
                            : (message.hasError
                                  ? 'failed'
                                  : (message.isSending ? 'sending' : 'sent')),
                      )
                    : null,
                reactionsChip:
                    message.reactions != null && message.reactions!.isNotEmpty
                    ? ReactionsChip(
                        reactions: message.reactions!,
                        isSent: isOwn,
                      )
                    : null,
                replyQuote: message.replyToMessage != null
                    ? ReplyQuoteBox(
                        username:
                            message.replyToMessage!.sender?.username ?? 'user',
                        text: message.replyToMessage!.content,
                        isSent: isOwn,
                      )
                    : null,
                child: _buildBubbleContent(
                  message,
                  isOwn,
                  isFirstInGroup,
                  isLastInGroup,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBubbleContent(
    Message message,
    bool isOwn,
    bool isFirst,
    bool isLast,
  ) {
    switch (message.messageType) {
      case 'image':
        return GestureDetector(
          onTap: () {
            context.push('/messages/image-viewer', extra: {
              'imageUrl': message.mediaUrl ?? '',
              'senderName': message.sender?.username,
              'timestamp': message.createdAt,
            });
          },
          child: ImageBubble(imageUrl: message.mediaUrl ?? '', isSent: isOwn),
        );
      case 'video':
        return GestureDetector(
          onTap: () {
            context.push('/messages/video-player', extra: {
              'videoUrl': message.mediaUrl ?? '',
              'thumbnailUrl': message.thumbnailUrl,
              'senderName': message.sender?.username,
            });
          },
          child: VideoBubble(
            thumbnailUrl: message.thumbnailUrl ?? message.mediaUrl ?? '',
            duration: "0:24",
            isSent: isOwn,
          ),
        );
      case 'audio':
        return AudioBubble(
          audioUrl: message.mediaUrl ?? '',
          isSent: isOwn,
        );
      default:
        return TextBubble(
          text: message.isEdited ? '${message.content} (edited)' : message.content,
          isSent: isOwn,
          isFirstInGroup: isFirst,
          isLastInGroup: isLast,
        );
    }
  }
}

class _DateDivider extends StatelessWidget {
  final String text;
  const _DateDivider({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? CupertinoColors.white.withOpacity(0.08)
                : CupertinoColors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(text, style: ChatUIConstants.dateDividerStyle(isDark)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.messageCircle,
            size: 56,
            color: isDark
                ? CupertinoColors.white.withOpacity(0.15)
                : CupertinoColors.black.withOpacity(0.08),
          ),
          const SizedBox(height: 14),
          Text(
            "No messages yet",
            style: TextStyle(
              fontSize: 15,
              color: isDark
                  ? ChatUIConstants.textSecondaryDark
                  : ChatUIConstants.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Send a message to get started",
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? CupertinoColors.white.withOpacity(0.25)
                  : const Color(0xFFBBBBBB),
            ),
          ),
        ],
      ),
    );
  }
}
