// lib/features/chat/presentation/bubbles/text_bubble.dart

import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../../../core/theme/chat_theme.dart';

class TextBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isFirst;
  final bool isLast;
  final bool isDark;

  const TextBubble({
    super.key,
    required this.message,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
  });

  BorderRadius _radius() {
    const r = ChatDimens.bubbleRadius;
    const t = ChatDimens.bubbleTailRadius;
    final isMe = message.isFromMe;
    
    if (isMe) {
      return BorderRadius.only(
        topLeft: const Radius.circular(r),
        topRight: Radius.circular(isFirst ? r : t),
        bottomLeft: const Radius.circular(r),
        bottomRight: Radius.circular(isLast ? t : r),
      );
    }
    return BorderRadius.only(
      topLeft: Radius.circular(isFirst ? r : t),
      topRight: const Radius.circular(r),
      bottomLeft: Radius.circular(isLast ? t : r),
      bottomRight: const Radius.circular(r),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromMe;
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width *
            ChatDimens.bubbleMaxWidth,
        minWidth: 42,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: ChatDimens.bubblePadH,
        vertical: ChatDimens.bubblePadV,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? ChatColors.sentBlue
            : (isDark
                ? ChatColors.receivedDark
                : ChatColors.receivedLight),
        borderRadius: _radius(),
      ),
      child: Text(
        message.text ?? '',
        style: ChatTextStyles.message(
          color: isMe
              ? Colors.white
              : (isDark
                  ? ChatColors.primaryDark
                  : ChatColors.primaryLight),
        ),
      ),
    );
  }
}
