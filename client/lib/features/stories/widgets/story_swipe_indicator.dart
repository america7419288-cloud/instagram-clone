import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story_model.dart';

enum SwipeDirection { left, right }

class StorySwipeIndicator extends StatelessWidget {
  final StoryUserModel user;
  final SwipeDirection direction;
  final double dragProgress; // 0.0 → 1.0

  const StorySwipeIndicator({
    super.key,
    required this.user,
    required this.direction,
    required this.dragProgress,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = direction == SwipeDirection.left;
    final opacity = (dragProgress * 1.5).clamp(0.0, 1.0);
    final slideOffset = (1.0 - dragProgress) * 40.0;

    return Positioned(
      left: isLeft ? 16 : null,
      right: isLeft ? null : 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(isLeft ? slideOffset : -slideOffset, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user.avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.black54),
                      errorWidget: (_, __, ___) => const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 4,
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
