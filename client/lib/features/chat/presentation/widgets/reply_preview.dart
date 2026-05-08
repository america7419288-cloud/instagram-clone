// lib/features/chat/presentation/widgets/reply_preview.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/message.dart';
import '../../../../core/theme/chat_theme.dart';

class ReplyPreview extends StatelessWidget {
  final ChatMessage reply;
  final VoidCallback onClear;

  const ReplyPreview({
    super.key,
    required this.reply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? ChatColors.black : ChatColors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? ChatColors.darkBorder : ChatColors.separatorLight,
            width: 0.5,
          ),
        ),
      ),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isDark ? ChatColors.darkCard : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: ChatColors.blue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Text content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replying to ${reply.senderName}',
                    style: TextStyle(
                      color: ChatColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: ChatTextStyles.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reply.previewText,
                    style: TextStyle(
                      color: isDark ? ChatColors.primaryDark : ChatColors.primaryLight,
                      fontSize: 13,
                      fontFamily: ChatTextStyles.fontFamily,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Thumbnail for media
            if (reply.thumbnailUrl != null || reply.mediaUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    reply.thumbnailUrl ?? reply.mediaUrl!,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Clear button
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  LucideIcons.x,
                  size: 16,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
