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
import '../../../chat/data/models/chat_user.dart';
import '../../../chat/presentation/widgets/group_info_sheet.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

// UI Components
import '../widgets/chat/chat_ui_constants.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/chat/message_bubbles.dart';
import '../widgets/chat/message_bubble_wrapper.dart';
import '../widgets/chat/chat_overlays.dart';
import '../widgets/chat/popup_menu/message_popup_menu.dart';
import 'package:flutter/material.dart' show Colors, Material, Divider, CircleAvatar;
import '../widgets/chat/reaction_overlay.dart';
import '../widgets/chat/message_edit_dialog.dart';
import '../widgets/chat/disappearing_message_dialog.dart';
import '../../../../shared/widgets/user_story_avatar.dart';
import '../../../../shared/widgets/verified_badge.dart';

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

    // Mark as read when entering (if conversation is accepted)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isAccepted = widget.conversation?.isAccepted ??
          ref.read(inboxProvider).conversations.any((c) => c.id == widget.conversationId);
      if (isAccepted) {
        ref.read(chatProvider(widget.conversationId).notifier).markAsRead();
      }
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
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Popup',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return MessagePopupMenu(
          message: message,
          messageWidget: Material(
            color: Colors.transparent,
            child: _buildBubbleContent(
              message,
              isOwn,
              true,
              true,
            ),
          ),
          messagePosition: offset,
          messageSize: size,
          isMine: isOwn,
          onDismiss: () => Navigator.of(context).pop(),
          onReact: (emoji) {
            ref
                .read(chatProvider(widget.conversationId).notifier)
                .addReaction(message.id, emoji);
          },
          onReply: () {
            setState(() => _replyingTo = message);
            _inputFocusNode.requestFocus();
          },
          onCopy: () {
            Clipboard.setData(ClipboardData(text: message.content));
            HapticFeedback.lightImpact();
          },
          onForward: () {
            context.push('/messages/forward', extra: message);
          },
          onUnsend: () {
            ref
                .read(chatProvider(widget.conversationId).notifier)
                .deleteMessage(message.id);
          },
          onReport: () {
            // TODO: Implement report functionality
          },
          onSave: () {
            HapticFeedback.lightImpact();
            // TODO: Implement save functionality
          },
          onCopyLink: () {
            Clipboard.setData(ClipboardData(text: 'https://instagram.com/p/placeholder'));
            HapticFeedback.lightImpact();
          },
        );
      },
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
              orElse: () => ref
                  .watch(inboxProvider)
                  .requests
                  .firstWhere(
                    (c) => c.id == widget.conversationId,
                    orElse: () => Conversation(
                      id: '',
                      participants: const [],
                      updatedAt: DateTime.now(),
                      isAccepted: true, // Default to true if not found in either
                    ),
                  ),
            );

    final currentUserId = currentUser?.id ?? '';
    final onlyAdminsCanSend = conversation.isGroup && (conversation.onlyAdminsCanSend ?? false);
    final participant = conversation.participants.firstWhere(
      (p) => p.id == currentUserId,
      orElse: () => ChatUser(id: '', username: '', role: 'member'),
    );
    final isCurrentUserAdmin = participant.role == 'admin';

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
              username: conversation.isGroup
                  ? (conversation.name ?? 'Group Chat')
                  : (otherUser?.username ?? 'Chat'),
              avatarUrl: conversation.isGroup
                  ? conversation.avatarUrl
                  : otherUser?.profilePicUrl,
              userId: conversation.isGroup ? null : otherUser?.id,
              statusText: conversation.isGroup
                  ? '${conversation.participants.length} members'
                  : statusText,
              isOnline: conversation.isGroup ? false : isOnline,
              isVerified: conversation.isGroup ? false : (otherUser?.isVerified ?? false),
              hasStory: !conversation.isGroup,
              onProfileTap: () {
                if (conversation.isGroup) {
                  HapticFeedback.mediumImpact();
                  GroupInfoSheet.show(
                    context,
                    conversation: conversation,
                  );
                } else {
                  _openProfile(otherUser?.username);
                }
              },
              onMoreTap: () {
                if (conversation.isGroup) {
                  HapticFeedback.mediumImpact();
                  GroupInfoSheet.show(
                    context,
                    conversation: conversation,
                  );
                } else {
                  _showChatOptions();
                }
              },
            ),

            Expanded(
              child: ClipRect(
                clipper: BottomOverflowClipper(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildMessageList(chatState, currentUser?.id ?? '', conversation, otherUser, isDark),

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
            ),

            if (conversation.isAccepted == false)
              _buildRequestPreviewBlock(context, conversation, isDark)
            else ...[
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

              if (onlyAdminsCanSend && !isCurrentUserAdmin)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? ChatUIConstants.bgDark : ChatUIConstants.bgLight,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? ChatUIConstants.separatorDark
                            : ChatUIConstants.separatorLight,
                        width: 0.33,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "Only admins can send messages",
                      style: TextStyle(
                        fontFamily: ChatUIConstants.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? ChatUIConstants.textSecondaryDark
                            : ChatUIConstants.textSecondaryLight,
                      ),
                    ),
                  ),
                )
              else
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
          ],
        ),
      ),
    );
  }

  Widget _buildRequestPreviewBlock(
    BuildContext context,
    Conversation conversation,
    bool isDark,
  ) {
    final otherUser = conversation.otherUser;
    final displayName = otherUser?.username ?? 'this user';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : const Color(0xFFF9F9F9),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[950]! : Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.info,
                size: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "The sender won't know you've seen this until you accept. You can choose to accept or decline future messages from $displayName.",
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontFamily: 'SF Pro Text',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final confirm = await showCupertinoModalPopup<bool>(
                      context: context,
                      builder: (context) => CupertinoActionSheet(
                        title: Text('Delete message request from $displayName?'),
                        message: const Text('This will delete the chat history. They won\'t be notified, but they can still message you again if you haven\'t blocked them.'),
                        actions: [
                          CupertinoActionSheetAction(
                            isDestructiveAction: true,
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                        cancelButton: CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                    );

                    if (confirm == true && context.mounted) {
                      ref.read(inboxProvider.notifier).rejectRequest(conversation.id);
                      context.pop();
                    }
                  },
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.red[400] : Colors.red[600],
                        fontFamily: 'SF Pro Text',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ref.read(inboxProvider.notifier).acceptRequest(conversation.id);
                    if (context.mounted) {
                      ref.read(chatProvider(conversation.id).notifier).markAsRead();
                    }
                  },
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF3797EF),
                          Color(0xFF007FFF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3797EF).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'SF Pro Text',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(
      ChatState state, String currentUserId, Conversation conversation, ChatUser? otherUser, bool isDark) {
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
      clipBehavior: Clip.none,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: state.messages.length + (state.messages.isEmpty ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == state.messages.length) {
          // Earliest message top - render the IG standard chat profile preview banner!
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Big Avatar
                if (conversation.isGroup)
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                      shape: BoxShape.circle,
                      image: conversation.avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(conversation.avatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: conversation.avatarUrl == null
                        ? Icon(LucideIcons.users, size: 36, color: isDark ? Colors.white54 : Colors.black45)
                        : null,
                  )
                else if (otherUser != null)
                  UserStoryAvatar(
                    userId: otherUser.id,
                    profilePicUrl: otherUser.profilePicUrl,
                    username: otherUser.username,
                    size: 72,
                    showPresence: false,
                    isClickable: true,
                  )
                else
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.user, 
                      size: 36, 
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                const SizedBox(height: 12),
                
                // 2. Username with Verified Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        conversation.isGroup 
                            ? (conversation.name ?? 'Group Chat') 
                            : (otherUser?.username ?? 'Instagram User'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Instagram-Sans',
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!conversation.isGroup && (otherUser?.isVerified ?? false)) ...[
                      const SizedBox(width: 4),
                      const VerifiedBadge(size: 15),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                
                // 3. Full Name
                if (conversation.isGroup) ...[
                   Text(
                     '${conversation.participants.length} members',
                     style: TextStyle(
                       fontSize: 13,
                       fontWeight: FontWeight.w400,
                       color: isDark ? Colors.white54 : Colors.black54,
                     ),
                   ),
                   const SizedBox(height: 16),
                ] else if (otherUser?.fullName != null) ...[
                  Text(
                    otherUser!.fullName!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // 4. View Profile Button
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(8),
                  minSize: 0,
                  onPressed: () {
                    if (conversation.isGroup) {
                      GroupInfoSheet.show(
                        context,
                        conversation: conversation,
                      );
                    } else {
                      _openProfile(otherUser?.username);
                    }
                  },
                  child: Text(
                    conversation.isGroup ? 'View Group' : 'View Profile',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                ),
              ],
            ),
          );
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
          final mDate = message.createdAt;
          final pDate = prevMsg.createdAt;
          if (mDate.year != pDate.year ||
              mDate.month != pDate.month ||
              mDate.day != pDate.day) {
            showDateDivider = true;
          }
        }

        final isNewSent = index == 0 &&
            isOwn &&
            (message.isSending ||
                DateTime.now().difference(message.createdAt).inMilliseconds < 1500);

        return TweenAnimationBuilder<double>(
          key: ValueKey(message.id),
          tween: Tween(begin: 0, end: 1),
          duration: isNewSent
              ? const Duration(milliseconds: 400)
              : Duration(milliseconds: 180 + (index % 4) * 28),
          curve: isNewSent ? Curves.easeOutBack : Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - value) * (isNewSent ? 120.0 : 10.0)),
                child: Transform.scale(
                  scale: isNewSent ? (0.4 + (value * 0.6)) : 1.0,
                  alignment: Alignment.bottomRight,
                  child: child,
                ),
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
                onAvatarTap: () {
                  final username = message.sender?.username;
                  if (username != null && username.isNotEmpty) {
                    context.push('/profile/${Uri.encodeComponent(username)}');
                  }
                },
                onReply: () {
                  setState(() => _replyingTo = message);
                  _inputFocusNode.requestFocus();
                },
                onDoubleTap: () {
                  _handleLike();
                  final size = MediaQuery.of(context).size;
                  _showHeartBurst(Offset(size.width / 2, size.height / 2));
                },
                onLongPress: (offset, size) {
                  HapticFeedback.heavyImpact();
                  _showMessageOptions(
                    context,
                    message,
                    isOwn,
                    offset,
                    size,
                  );
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
      case 'post':
        return SharedPostBubble(
          sharedUsername: message.sharedUsername,
          sharedCaption: message.sharedCaption,
          sharedThumbnailUrl: message.sharedThumbnailUrl,
          messageType: 'post',
          isSent: isOwn,
          onTap: () {
            if (message.postId != null && message.postId!.isNotEmpty) {
              context.push('/post/${message.postId}');
            }
          },
        );
      case 'reel':
        return SharedPostBubble(
          sharedUsername: message.sharedUsername,
          sharedCaption: message.sharedCaption,
          sharedThumbnailUrl: message.sharedThumbnailUrl,
          messageType: 'reel',
          isSent: isOwn,
          onTap: () {
            if (message.reelId != null && message.reelId!.isNotEmpty) {
              context.push('/reel/${message.reelId}');
            }
          },
        );
      case 'story':
        return SharedPostBubble(
          sharedUsername: message.sharedUsername,
          sharedCaption: message.sharedCaption,
          sharedThumbnailUrl: message.sharedThumbnailUrl,
          messageType: 'story',
          isSent: isOwn,
          onTap: () {
            if (message.storyId != null && message.storyId!.isNotEmpty) {
              context.push('/story/${message.storyId}');
            }
          },
        );
      default:
        final content = message.content;
        if (content.startsWith('[note_reply]:')) {
          final parts = content.substring('[note_reply]:'.length).split('|');
          final String noteText = parts.isNotEmpty ? parts[0] : '';
          final String replyText = parts.length > 1 ? parts.sublist(1).join('|') : '';
          return _buildNoteReplyBubble(
            noteText,
            replyText,
            isOwn,
            isFirst,
            isLast,
          );
        }
        return TextBubble(
          text: message.isEdited ? '${message.content} (edited)' : message.content,
          isSent: isOwn,
          isFirstInGroup: isFirst,
          isLastInGroup: isLast,
        );
    }
  }

  Widget _buildNoteReplyBubble(
    String noteText,
    String replyText,
    bool isOwn,
    bool isFirst,
    bool isLast,
  ) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    
    final bubbleColor = isOwn
        ? ChatUIConstants.bubbleSent
        : (isDark
            ? ChatUIConstants.bubbleReceivedDark
            : ChatUIConstants.bubbleReceivedLight);

    final cardBgColor = isOwn
        ? CupertinoColors.white.withOpacity(0.18)
        : (isDark
            ? CupertinoColors.white.withOpacity(0.08)
            : CupertinoColors.black.withOpacity(0.05));

    final cardTextColor = isOwn
        ? CupertinoColors.white.withOpacity(0.9)
        : (isDark
            ? ChatUIConstants.textPrimaryDark.withOpacity(0.85)
            : ChatUIConstants.textPrimaryLight.withOpacity(0.85));

    final accentBarColor = isOwn
        ? CupertinoColors.white.withOpacity(0.6)
        : const Color(0xFF0095F6);

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: isOwn
          ? (isFirst
                ? const Radius.circular(18)
                : const Radius.circular(6))
          : const Radius.circular(18),
      bottomLeft: isOwn
          ? const Radius.circular(18)
          : (isLast
                ? const Radius.circular(6)
                : const Radius.circular(18)),
      bottomRight: isOwn
          ? (isLast
                ? const Radius.circular(6)
                : const Radius.circular(18))
          : const Radius.circular(18),
    );

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
        minWidth: 120,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: borderRadius,
        border: isOwn
            ? null
            : Border.all(
                color: isDark
                    ? const Color(0xFF303030)
                    : const Color(0xFFE9E9E9),
                width: 0.4,
              ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // QUOTED NOTE CARD
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent left border bar
                Container(
                  width: 3.5,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentBarColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Metadata Row
                      Row(
                        children: [
                          Icon(
                            LucideIcons.messageSquare,
                            size: 11,
                            color: cardTextColor.withOpacity(0.65),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOwn ? 'You replied to note' : 'Replied to your note',
                            style: TextStyle(
                              fontFamily: ChatUIConstants.fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: cardTextColor.withOpacity(0.65),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Quoted Note text
                      Text(
                        noteText,
                        style: TextStyle(
                          fontFamily: ChatUIConstants.fontFamily,
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: cardTextColor,
                          height: 1.25,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),

          // REPLY BODY TEXT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              replyText,
              style: ChatUIConstants.messageStyle(isOwn, isDark),
            ),
          ),
        ],
      ),
    );
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

class BottomOverflowClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width, size.height + 250);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

