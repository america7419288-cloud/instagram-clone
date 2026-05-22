// lib/features/inbox/widgets/conversation_avatar.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/conversation_model.dart';
import 'pulsing_dot.dart';

class ConversationAvatar extends StatelessWidget {
  final ConversationModel conversation;

  const ConversationAvatar({
    super.key,
    required this.conversation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;

    if (conversation.isGroup) {
      return _buildGroupAvatar(isDark, bgColor);
    }

    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Main avatar with optional story ring
          conversation.hasStory
              ? _buildWithStoryRing()
              : _buildPlainAvatar(56),

          // Online dot
          if (conversation.isActive || conversation.lastActiveTime != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: conversation.isActive
                  ? const PulsingDot(size: 12)
                  : Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF09C167),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: bgColor,
                          width: 2,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupAvatar(bool isDark, Color bgColor) {
    final avatars = conversation.groupAvatars;
    final String backAvatarUrl = avatars.isNotEmpty ? avatars[0] : '';
    final String frontAvatarUrl = avatars.length > 1 ? avatars[1] : '';

    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        children: [
          // Main/Back Avatar
          Positioned(
            left: 0,
            top: 2,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: bgColor, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: backAvatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: backAvatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (c, u, e) => _buildPlaceholder(20),
                      )
                    : _buildPlaceholder(20),
              ),
            ),
          ),
          // Secondary/Front Avatar
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: bgColor, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: frontAvatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: frontAvatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (c, u, e) => _buildPlaceholder(16),
                      )
                    : _buildPlaceholder(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithStoryRing() {
    return Container(
      width: 62,
      height: 62,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(0xFFF58529),
            Color(0xFFDD2A7B),
            Color(0xFF8134AF),
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _buildPlainAvatar(52),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlainAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: conversation.avatarUrl,
          fit: BoxFit.cover,
          placeholder: (c, u) => Container(color: Colors.grey.withValues(alpha: 0.2)),
          errorWidget: (c, u, e) => _buildPlaceholder(size / 2 - 4),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(double radius) {
    return Container(
      color: Colors.grey.withValues(alpha: 0.2),
      child: Icon(Icons.person, color: Colors.grey, size: radius),
    );
  }
}
