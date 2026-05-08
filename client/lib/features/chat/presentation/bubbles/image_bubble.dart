// lib/features/chat/presentation/bubbles/image_bubble.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/message.dart';
import '../../../../core/theme/chat_theme.dart';

class ImageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const ImageBubble({
    super.key,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromMe;
    final viewed = message.isViewed;
    final isDisappearing = message.isDisappearing;

    // Disappearing Photo - Not viewed
    if (isDisappearing && !viewed) {
      return Container(
        width: 220,
        height: 48,
        decoration: BoxDecoration(
          color: isMe
              ? ChatColors.sentBlue
              : (isDark
                  ? ChatColors.receivedDark
                  : ChatColors.receivedLight),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isMe
                ? Colors.white.withOpacity(0.1)
                : ChatColors.blue.withOpacity(0.07),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.camera,
              size: 17,
              color: isMe ? Colors.white.withOpacity(0.8) : ChatColors.blue,
            ),
            const SizedBox(width: 8),
            Text(
              'Photo · Tap to view once',
              style: TextStyle(
                color: isMe ? Colors.white.withOpacity(0.8) : ChatColors.blue,
                fontSize: 13,
                fontFamily: ChatTextStyles.fontFamily,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Viewed
    if (isDisappearing && viewed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.camera,
              size: 16,
              color: ChatColors.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Viewed',
              style: TextStyle(
                color: ChatColors.secondary,
                fontSize: 14,
                fontFamily: ChatTextStyles.fontFamily,
              ),
            ),
          ],
        ),
      );
    }

    // Standard Image
    return ClipRRect(
      borderRadius: BorderRadius.circular(ChatDimens.bubbleRadius),
      child: Image.network(
        message.mediaUrl ?? 'https://picsum.photos/400/600',
        width: 230,
        height: 320,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 230,
          height: 320,
          color: isDark ? ChatColors.darkCard : const Color(0xFFEFEFEF),
          child: const Icon(LucideIcons.imageOff, color: ChatColors.secondary),
        ),
      ),
    );
  }
}
