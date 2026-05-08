// lib/features/chat/presentation/bubbles/deleted_bubble.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/message.dart';
import '../../../../core/theme/chat_theme.dart';

class DeletedBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const DeletedBubble({
    super.key,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromMe;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ChatDimens.bubbleRadius),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.12) : ChatColors.separatorLight,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.ban, size: 13, color: ChatColors.secondary),
          const SizedBox(width: 6),
          Text(
            isMe ? 'You unsent a message' : 'Message unsent',
            style: const TextStyle(
              color: ChatColors.secondary,
              fontSize: 14,
              fontFamily: ChatTextStyles.fontFamily,
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
