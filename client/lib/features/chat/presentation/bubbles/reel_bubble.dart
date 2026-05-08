// lib/features/chat/presentation/bubbles/reel_bubble.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/message.dart';
import '../../../../core/theme/chat_theme.dart';

class ReelBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const ReelBubble({
    super.key,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isReel = message.type == MessageType.reel;

    return Container(
      width: 238,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(ChatDimens.bubbleRadius),
        border: Border.all(
          color: isDark ? ChatColors.darkBorder : ChatColors.separatorLight,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: ChatColors.receivedLight,
                  child: const Icon(LucideIcons.user, size: 11, color: ChatColors.secondary),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    message.sharedUsername ?? 'username',
                    style: TextStyle(
                      color: isDark ? ChatColors.primaryDark : ChatColors.primaryLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: ChatTextStyles.fontFamily,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isReel)
                  const Icon(LucideIcons.film, size: 13, color: ChatColors.secondary),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Stack(
              children: [
                Image.network(
                  message.thumbnailUrl ?? 'https://picsum.photos/400/600',
                  width: 238,
                  height: isReel ? 300 : 238,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 238,
                    height: 200,
                    color: ChatColors.receivedLight,
                    child: const Icon(LucideIcons.imageOff, color: ChatColors.secondary, size: 32),
                  ),
                ),
                if (isReel)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.42),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.play, color: Colors.white, size: 19),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 10),
            child: Text(
              message.sharedCaption ?? '',
              style: TextStyle(
                color: isDark ? ChatColors.primaryDark.withOpacity(0.6) : ChatColors.secondary,
                fontSize: 12,
                fontFamily: ChatTextStyles.fontFamily,
                decoration: TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
