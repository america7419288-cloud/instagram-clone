// lib/features/chat/presentation/widgets/message_bubble_wrapper.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/message.dart';
import '../bubbles/text_bubble.dart';
import '../bubbles/image_bubble.dart';
import '../bubbles/audio_bubble.dart';
import '../bubbles/video_bubble.dart';
import '../bubbles/reel_bubble.dart';
import '../bubbles/deleted_bubble.dart';
import '../../../../core/theme/chat_theme.dart';

class MessageBubbleWrapper extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 8.0 : 2.0,
      ),
      child: GestureDetector(
        onLongPress: onLongPress,
        onDoubleTap: onDoubleTap,
        child: _SwipeToReply(
          onSwipe: onSwipeReply,
          isMe: message.isFromMe,
          child: Row(
            mainAxisAlignment: message.isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!message.isFromMe) ...[
                if (isLast)
                  _Avatar(url: message.senderAvatar)
                else
                  const SizedBox(width: 28),
                const SizedBox(width: 8),
              ],
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (message.isDeleted) {
      return DeletedBubble(message: message, isDark: isDark);
    }

    switch (message.type) {
      case MessageType.text:
        return TextBubble(
          message: message,
          isFirst: isFirst,
          isLast: isLast,
          isDark: isDark,
        );
      case MessageType.image:
        return GestureDetector(
          onTap: () => onTapImage(message.mediaUrl!),
          child: ImageBubble(message: message, isDark: isDark),
        );
      case MessageType.audio:
        return AudioBubble(message: message, isDark: isDark);
      case MessageType.video:
        return VideoBubble(message: message, isDark: isDark);
      case MessageType.reel:
        return ReelBubble(message: message, isDark: isDark);
      default:
        return TextBubble(
          message: message,
          isFirst: isFirst,
          isLast: isLast,
          isDark: isDark,
        );
    }
  }
}

class _Avatar extends StatelessWidget {
  final String? url;

  const _Avatar({this.url});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: const Color(0xFFEFEFEF),
      backgroundImage: url != null ? NetworkImage(url!) : null,
      child: url == null
          ? const Icon(LucideIcons.user, size: 12, color: ChatColors.secondary)
          : null,
    );
  }
}

class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipe;
  final bool isMe;

  const _SwipeToReply({
    required this.child,
    required this.onSwipe,
    required this.isMe,
  });

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _offset = 0;
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _offset += details.delta.dx * 0.4;
          // Clamp based on sender
          if (widget.isMe) {
            _offset = _offset.clamp(-60, 0);
          } else {
            _offset = _offset.clamp(0, 60);
          }
          
          if (_offset.abs() > 40 && !_triggered) {
            _triggered = true;
            HapticFeedback.lightImpact();
          }
        });
      },
      onHorizontalDragEnd: (details) {
        if (_triggered) {
          widget.onSwipe();
        }
        setState(() {
          _offset = 0;
          _triggered = false;
        });
      },
      child: Stack(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          if (_offset != 0)
            Positioned(
              left: widget.isMe ? null : 10,
              right: widget.isMe ? 10 : null,
              child: Opacity(
                opacity: (_offset.abs() / 40).clamp(0, 1),
                child: const Icon(LucideIcons.reply, size: 20, color: ChatColors.secondary),
              ),
            ),
          Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
