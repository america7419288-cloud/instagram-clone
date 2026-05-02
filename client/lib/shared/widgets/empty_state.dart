import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.buttonLabel,
    this.onButton,
    this.iconSize = 64,
  });

  const EmptyState.feed({super.key})
    : icon = Icons.image_outlined,
      title = 'No posts yet',
      subtitle = 'Follow people to see their posts here',
      buttonLabel = null,
      onButton = null,
      iconSize = 64;

  const EmptyState.notifications({super.key})
    : icon = Icons.notifications_none_outlined,
      title = 'No notifications yet',
      subtitle =
          'When someone likes or comments\non your posts, you\'ll see it here',
      buttonLabel = null,
      onButton = null,
      iconSize = 64;

  const EmptyState.messages({super.key})
    : icon = Icons.chat_bubble_outline,
      title = 'No messages yet',
      subtitle = 'Start a conversation with someone\nyou follow',
      buttonLabel = 'Send message',
      onButton = null,
      iconSize = 64;

  const EmptyState.search({super.key})
    : icon = Icons.search,
      title = 'Search',
      subtitle = 'Find accounts, hashtags\nand more',
      buttonLabel = null,
      onButton = null,
      iconSize = 64;

  const EmptyState.posts({super.key})
    : icon = Icons.grid_on_outlined,
      title = 'No posts yet',
      subtitle = null,
      buttonLabel = null,
      onButton = null,
      iconSize = 64;

  const EmptyState.saved({super.key})
    : icon = Icons.bookmark_outline,
      title = 'Save photos and videos',
      subtitle =
          'Save things that you want to\nsee again. No one is notified.',
      buttonLabel = null,
      onButton = null,
      iconSize = 64;

  const EmptyState.comments({super.key})
    : icon = Icons.chat_bubble_outline,
      title = 'No comments yet',
      subtitle = 'Start the conversation.',
      buttonLabel = null,
      onButton = null,
      iconSize = 48;

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        isDark ? const Color(0xFF555555) : const Color(0xFFDBDBDB);
    final titleColor =
        isDark ? const Color(0xFFFFFFFF) : const Color(0xFF262626);
    final subColor =
        isDark ? const Color(0xFFA8A8A8) : const Color(0xFF737373);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: titleColor,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: subColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (buttonLabel != null && onButton != null) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: onButton,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF0095F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  buttonLabel!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
