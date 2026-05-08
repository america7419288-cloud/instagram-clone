// lib/features/chat/presentation/bubbles/video_bubble.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/message.dart';
import '../../../../core/theme/chat_theme.dart';

class VideoBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const VideoBubble({
    super.key,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ChatDimens.bubbleRadius),
      child: Stack(
        children: [
          Image.network(
            message.thumbnailUrl ?? 'https://picsum.photos/400/600',
            width: 220,
            height: 280,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 220,
              height: 280,
              color: Colors.black87,
              child: const Icon(LucideIcons.video, color: Colors.white38, size: 40),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.38)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.play, color: Colors.white, size: 21),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 10,
            child: Text(
              message.videoDuration ?? '0:15',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: ChatTextStyles.fontFamily,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
