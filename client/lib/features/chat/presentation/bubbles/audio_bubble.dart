// lib/features/chat/presentation/bubbles/audio_bubble.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/message.dart';
import '../../../../core/theme/chat_theme.dart';

class AudioBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const AudioBubble({
    super.key,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromMe;
    final color = isMe
        ? Colors.white
        : (isDark ? ChatColors.primaryDark : ChatColors.primaryLight);

    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? ChatColors.sentBlue
            : (isDark ? ChatColors.receivedDark : ChatColors.receivedLight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.play, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                12,
                (i) => Container(
                  width: 2,
                  height: 10 + (i % 3) * 5,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            message.audioDuration ?? '0:04',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontFamily: ChatTextStyles.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
