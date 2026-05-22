// lib/features/inbox/widgets/message_requests_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessageRequestsTile extends StatefulWidget {
  final int count;
  final List<String> avatarUrls;
  final VoidCallback onTap;

  const MessageRequestsTile({
    super.key,
    required this.count,
    required this.avatarUrls,
    required this.onTap,
  });

  @override
  State<MessageRequestsTile> createState() => _MessageRequestsTileState();
}

class _MessageRequestsTileState extends State<MessageRequestsTile>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final dividerColor = Colors.grey.withValues(alpha: 0.2);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressController.reverse(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: dividerColor, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // STACKED AVATARS
              _buildStackedAvatars(isDark),
              const SizedBox(width: 12),

              // MESSAGE REQUESTS LABEL & COUNT
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Message requests',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${widget.count})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // '>' CHEVRON
              Icon(
                LucideIcons.chevron_right,
                size: 20,
                color: Colors.grey.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStackedAvatars(bool isDark) {
    final urls = widget.avatarUrls;
    if (urls.isEmpty) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.users, size: 18, color: Colors.grey),
      );
    }

    if (urls.length == 1) {
      return Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: CachedNetworkImage(
            imageUrl: urls[0],
            fit: coverFit(),
            placeholder: (context, url) => Container(color: Colors.grey.withValues(alpha: 0.3)),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey.withValues(alpha: 0.3),
              child: const Icon(LucideIcons.user, size: 16),
            ),
          ),
        ),
      );
    }

    // Show 2 stacked avatars
    final borderColor = isDark ? Colors.black : Colors.white;

    return SizedBox(
      width: 54, // 36px diameter + 18px offset
      height: 36,
      child: Stack(
        children: [
          // First (back) avatar
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CachedNetworkImage(
                  imageUrl: urls[0],
                  fit: coverFit(),
                  placeholder: (context, url) => Container(color: Colors.grey.withValues(alpha: 0.3)),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.withValues(alpha: 0.3),
                    child: const Icon(LucideIcons.user, size: 16),
                  ),
                ),
              ),
            ),
          ),
          // Second (front) avatar
          Positioned(
            left: 18,
            top: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CachedNetworkImage(
                  imageUrl: urls[1],
                  fit: coverFit(),
                  placeholder: (context, url) => Container(color: Colors.grey.withValues(alpha: 0.3)),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.withValues(alpha: 0.3),
                    child: const Icon(LucideIcons.user, size: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxFit coverFit() => BoxFit.cover;
}
