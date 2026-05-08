// lib/features/chat/presentation/chat_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../controller/chat_controller.dart';
import '../models/message.dart';
import '../../../../core/theme/chat_theme.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/message_list.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/reply_preview.dart';
import 'widgets/reaction_overlay.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String username;
  final String? avatarUrl;
  final bool isOnline;
  final bool isVerified;
  final bool hasStory;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.username,
    this.avatarUrl,
    this.isOnline = false,
    this.isVerified = false,
    this.hasStory = false,
  });

  @override
  State<ChatScreen> createState() =>
      _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver {

  late final ChatController _controller;
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  bool _showScrollFab = false;
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = ChatController(
        conversationId: widget.conversationId);
    _controller.init();
    _controller.addListener(_rebuild);

    _textController = TextEditingController();
    _focusNode = FocusNode();

    _textController.addListener(() {
      final composing =
          _textController.text.isNotEmpty;
      if (composing != _isComposing) {
        setState(() => _isComposing = composing);
      }
      _controller.onTextChanged(_textController.text);
    });

    _controller.scrollController.addListener(() {
      if (!_controller.scrollController.hasClients) return;
      final pos =
          _controller.scrollController.position;
      final nearBottom =
          pos.maxScrollExtent - pos.pixels < 200;
      if (!nearBottom != _showScrollFab) {
        setState(
            () => _showScrollFab = !nearBottom);
      }
    });
  }

  void _rebuild() => setState(() {});

  @override
  void didChangeMetrics() {
    // Auto scroll when keyboard opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.scrollController.hasClients) {
        _controller.scrollController.animateTo(
          _controller.scrollController.position
              .maxScrollExtent,
          duration:
              const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isDark =
        mq.platformBrightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: CupertinoPageScaffold(
        backgroundColor:
            isDark ? ChatColors.black : ChatColors.white,
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: ChatTextStyles.fontFamily,
            decoration: TextDecoration.none,
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [

                // ── Main column
                Column(
                  children: [
                    // App bar
                    ChatAppBar(
                      username: widget.username,
                      avatarUrl: widget.avatarUrl,
                      isOnline: widget.isOnline,
                      isVerified: widget.isVerified,
                      hasStory: widget.hasStory,
                      isDark: isDark,
                      onBack: () =>
                          Navigator.of(context).pop(),
                      onInfoTap: () {},
                      onCall: () {},
                      onVideo: () {},
                    ),

                    // Messages
                    Expanded(
                      child: _controller.isLoading
                          ? _LoadingState()
                          : MessageList(
                              messages:
                                  _controller.messages,
                              isTyping:
                                  _controller.isTyping,
                              scrollController:
                                  _controller
                                      .scrollController,
                              isDark: isDark,
                              onLongPress:
                                  _onMessageLongPress,
                              onSwipeReply: (msg) {
                                _controller
                                    .setReply(msg);
                                _focusNode
                                    .requestFocus();
                              },
                              onDoubleTap: (msg) {
                                _controller.react(
                                    msg.id, '❤️');
                              },
                              onTapImage: (url) {
                                _openImageViewer(url);
                              },
                            ),
                    ),

                    // Reply preview
                    if (_controller.replyingTo != null)
                      ReplyPreview(
                        reply: _controller.replyingTo!,
                        onClear: _controller.clearReply,
                      ),

                    // Input bar
                    ChatInputBar(
                      textController: _textController,
                      focusNode: _focusNode,
                      isComposing: _isComposing,
                      isRecording: _controller.isRecording,
                      recordingDuration: _controller.recordingDuration,
                      isDark: isDark,
                      onSend: _onSend,
                      onSendLike: _onSendLike,
                      onStartRecord: _controller.startRecording,
                      onStopRecord: _controller.stopRecording,
                      onCancelRecord: _controller.cancelRecording,
                      onGallery: () {},
                      onCamera: () {},
                    ),

                  ],
                ),

                // ── Scroll to bottom FAB
                if (_showScrollFab)
                  Positioned(
                    right: 16,
                    bottom: 80 +
                        mq.padding.bottom,
                    child: _ScrollFab(
                      onTap: () {
                        _controller.scrollController
                            .animateTo(
                          _controller.scrollController
                              .position.maxScrollExtent,
                          duration: const Duration(
                              milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      isDark: isDark,
                    ),
                  ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────

  void _onSend() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    _controller.sendText(text);
  }

  void _onSendLike() {
    _controller.sendText('❤️');
  }

  void _onMessageLongPress(ChatMessage message) {
    HapticFeedback.heavyImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim, secAnim) => ReactionOverlay(
        message: message,
        animation: anim,
        onReact: (emoji) {
          Navigator.pop(ctx);
          _controller.react(message.id, emoji);
        },
        onReply: () {
          Navigator.pop(ctx);
          _controller.setReply(message);
          _focusNode.requestFocus();
        },
        onCopy: () {
          Navigator.pop(ctx);
          if (message.text != null) {
            Clipboard.setData(ClipboardData(text: message.text!));
          }
        },
        onForward: () => Navigator.pop(ctx),
        onUnsend: message.isFromMe
            ? () {
                Navigator.pop(ctx);
                _confirmUnsend(message);
              }
            : null,
        onDelete: () {
          Navigator.pop(ctx);
          _controller.deleteForMe(message.id);
        },
      ),
    );
  }

  void _confirmUnsend(ChatMessage message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Unsend Message?'),
        content: const Text(
            'This will remove the message for everyone '
            'in the chat.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _controller.unsend(message.id);
            },
            child: const Text('Unsend'),
          ),
        ],
      ),
    );
  }

  void _openImageViewer(String url) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            _ImageViewer(url: url),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(
                opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_rebuild);
    _controller.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

// ── Loading State ──────────────────────────

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CupertinoActivityIndicator(radius: 14),
    );
  }
}

// ── Scroll FAB ──────────────────────────────

class _ScrollFab extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _ScrollFab({
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark
              ? ChatColors.darkCard
              : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          LucideIcons.chevronDown,
          size: 18,
          color: isDark
              ? Colors.white
              : ChatColors.primaryLight,
        ),
      ),
    );
  }
}

// ── Image Viewer ───────────────────────────

class _ImageViewer extends StatelessWidget {
  final String url;

  const _ImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(url),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black
                          .withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
