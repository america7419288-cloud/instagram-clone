// lib/features/chat/presentation/widgets/message_bubble.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/message.dart';
import '../bubbles/text_bubble.dart';
import '../bubbles/image_bubble.dart';
import '../bubbles/audio_bubble.dart';
import '../bubbles/reel_bubble.dart';
import '../bubbles/deleted_bubble.dart';
import '../bubbles/video_bubble.dart';
import '../../../../core/theme/chat_theme.dart';

class MessageBubbleWrapper extends StatefulWidget {
  final ChatMessage message;
  final bool isFirst;
  final bool isLast;
  final bool isDark;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;
  final VoidCallback onDoubleTap;
  final Function(String) onTapImage;

  const MessageBubbleWrapper({
    super.key,
    required this.message,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
    required this.onLongPress,
    required this.onSwipeReply,
    required this.onDoubleTap,
    required this.onTapImage,
  });

  @override
  State<MessageBubbleWrapper> createState() =>
      _MessageBubbleWrapperState();
}

class _MessageBubbleWrapperState
    extends State<MessageBubbleWrapper>
    with SingleTickerProviderStateMixin {

  double _dragX = 0;
  bool _replyTriggered = false;

  late AnimationController _snapController;
  late Animation<double> _snapAnim;

  // Double tap heart
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final isMe = widget.message.isFromMe;
    final delta = d.delta.dx;

    // Right swipe for received, left for sent
    if (!isMe && delta > 0) {
      setState(() {
        _dragX = (_dragX + delta).clamp(0.0, 72.0);
      });
    } else if (isMe && delta < 0) {
      setState(() {
        _dragX = (_dragX + delta).clamp(-72.0, 0.0);
      });
    }

    if (!_replyTriggered && _dragX.abs() > 50) {
      _replyTriggered = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _onDragEnd(DragEndDetails _) {
    if (_dragX.abs() > 50) {
      widget.onSwipeReply();
    }
    _replyTriggered = false;

    // Animate snap back
    final startVal = _dragX;
    _snapAnim = Tween<double>(
            begin: startVal, end: 0)
        .animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutCubic,
    ));
    _snapAnim.addListener(() {
      setState(() => _dragX = _snapAnim.value);
    });
    _snapController
      ..reset()
      ..forward();
  }

  void _onDoubleTap() {
    widget.onDoubleTap();
    setState(() => _showHeart = true);
    HapticFeedback.lightImpact();
    Future.delayed(
        const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _showHeart = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message.isFromMe;

    return GestureDetector(
      onLongPress: widget.onLongPress,
      onDoubleTap: _onDoubleTap,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Padding(
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          top: widget.isFirst
              ? ChatDimens.senderGap
              : ChatDimens.groupGap,
          bottom: widget.isLast ? 2 : 0,
        ),
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [

                // Reply icon (received, appears on drag)
                if (!isMe)
                  _ReplyIcon(
                    offset: _dragX,
                    isDark: widget.isDark,
                  ),

                // Avatar (received only)
                if (!isMe)
                  _MessageAvatar(
                    message: widget.message,
                    isLast: widget.isLast,
                  ),

                // Bubble column
                Flexible(
                  child: Transform.translate(
                    offset: Offset(_dragX, 0),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment
                              .start,
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [

                        // Reply reference
                        if (widget.message.replyTo
                            != null)
                          _ReplyBox(
                            reply: widget
                                .message.replyTo!,
                            isMe: isMe,
                            isDark: widget.isDark,
                          ),

                        // Bubble content
                        _buildContent(context),

                        // Reactions
                        if (widget.message.reactions
                            .isNotEmpty)
                          _ReactionsChip(
                            reactions: widget
                                .message.reactions,
                            isMe: isMe,
                            isDark: widget.isDark,
                          ),

                        // Delivery status
                        if (isMe && widget.isLast)
                          _StatusRow(
                            status: widget
                                .message.status,
                          ),
                      ],
                    ),
                  ),
                ),

                // Reply icon (sent, appears on drag)
                if (isMe)
                  _ReplyIcon(
                    offset: _dragX,
                    isDark: widget.isDark,
                  ),

              ],
            ),

            // Double tap heart
            if (_showHeart)
              Positioned.fill(
                child: Center(
                  child: _HeartBurst(),
                ),
              ),

          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final m = widget.message;

    if (m.isDeleted) {
      return DeletedBubble(
        message: m,
        isDark: widget.isDark,
      );
    }

    switch (m.type) {
      case MessageType.text:
        if (m.isEmojiOnly) {
          return _EmojiBubble(text: m.text!);
        }
        return TextBubble(
          message: m,
          isFirst: widget.isFirst,
          isLast: widget.isLast,
          isDark: widget.isDark,
        );

      case MessageType.image:
        return ImageBubble(
          message: m,
          isDark: widget.isDark,
        );

      case MessageType.audio:
        return AudioBubble(
          message: m,
          isDark: widget.isDark,
        );

      case MessageType.video:
        return VideoBubble(
          message: m,
          isDark: widget.isDark,
        );

      case MessageType.reel:
      case MessageType.post:
        return ReelBubble(
          message: m,
          isDark: widget.isDark,
        );

      default:
        return TextBubble(
          message: m,
          isFirst: widget.isFirst,
          isLast: widget.isLast,
          isDark: widget.isDark,
        );
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }
}

// ── Sub Widgets ────────────────────────────

class _ReplyIcon extends StatelessWidget {
  final double offset;
  final bool isDark;

  const _ReplyIcon({
    required this.offset,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        (offset.abs() / 72).clamp(0.0, 1.0);
    return Opacity(
      opacity: progress,
      child: Transform.scale(
        scale: 0.5 + progress * 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 4),
          child: Icon(
            LucideIcons.cornerUpLeft,
            size: 20,
            color: isDark
                ? Colors.white.withOpacity(0.5)
                : ChatColors.secondary,
          ),
        ),
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  final ChatMessage message;
  final bool isLast;

  const _MessageAvatar({
    required this.message,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLast) return const SizedBox(width: 34);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFFEFEFEF),
        backgroundImage: message.senderAvatar != null
            ? NetworkImage(message.senderAvatar!)
            : null,
        child: message.senderAvatar == null
            ? Icon(
                LucideIcons.user,
                size: 13,
                color: ChatColors.secondary,
              )
            : null,
      ),
    );
  }
}

class _ReplyBox extends StatelessWidget {
  final ReplyData reply;
  final bool isMe;
  final bool isDark;

  const _ReplyBox({
    required this.reply,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      constraints:
          const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.fromLTRB(
          10, 8, 10, 8),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.black.withOpacity(0.18)
            : (isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.black.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Accent bar
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white
                        .withOpacity(0.55)
                    : ChatColors.blue,
                borderRadius:
                    BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),

            Flexible(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reply.senderName,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                              .withOpacity(0.85)
                          : ChatColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily:
                          ChatTextStyles.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reply.previewText,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                              .withOpacity(0.6)
                          : ChatColors.secondary,
                      fontSize: 12,
                      fontFamily:
                          ChatTextStyles.fontFamily,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            if (reply.previewImage != null) ...[
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(6),
                child: Image.network(
                  reply.previewImage!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReactionsChip extends StatelessWidget {
  final List<MessageReaction> reactions;
  final bool isMe;
  final bool isDark;

  const _ReactionsChip({
    required this.reactions,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, int>{};
    for (final r in reactions) {
      grouped[r.emoji] =
          (grouped[r.emoji] ?? 0) + 1;
    }

    return Container(
      margin: EdgeInsets.only(
        top: 4,
        left: isMe ? 0 : 32,
        right: isMe ? 4 : 0,
        bottom: 2,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2C2C2C)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3A3A3C)
              : const Color(0xFFEFEFEF),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: grouped.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text(
              e.value > 1
                  ? '${e.key} ${e.value}'
                  : e.key,
              style: const TextStyle(fontSize: 13),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final MessageStatus status;

  const _StatusRow({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String label;

    switch (status) {
      case MessageStatus.sending:
        icon = LucideIcons.clock;
        color = ChatColors.secondary;
        label = '';
        break;
      case MessageStatus.sent:
        icon = LucideIcons.check;
        color = ChatColors.secondary;
        label = '';
        break;
      case MessageStatus.delivered:
        icon = LucideIcons.checkCheck;
        color = ChatColors.secondary;
        label = '';
        break;
      case MessageStatus.seen:
        icon = LucideIcons.checkCheck;
        color = ChatColors.blue;
        label = 'Seen';
        break;
      case MessageStatus.failed:
        icon = LucideIcons.alertCircle;
        color = ChatColors.red;
        label = 'Failed';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(
          top: 3, right: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontFamily:
                    ChatTextStyles.fontFamily,
              ),
            ),
          const SizedBox(width: 2),
          Icon(icon, size: 11, color: color),
        ],
      ),
    );
  }
}

class _EmojiBubble extends StatelessWidget {
  final String text;

  const _EmojiBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final count = text.characters.length;
    final size = count == 1
        ? 52.0
        : count == 2
            ? 44.0
            : 36.0;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 4, vertical: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: size, height: 1.2),
      ),
    );
  }
}

class _HeartBurst extends StatefulWidget {
  @override
  State<_HeartBurst> createState() =>
      _HeartBurstState();
}

class _HeartBurstState extends State<_HeartBurst>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _scale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3)
            .chain(CurveTween(
                curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0)
            .chain(CurveTween(
                curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(
                curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_ctrl);

    _opacity = Tween(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.6, 1.0),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: const Text(
            '❤️',
            style: TextStyle(fontSize: 72),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
