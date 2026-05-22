import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/providers/presence_provider.dart';
import '../../features/story/presentation/providers/story_provider.dart';
import 'story_ring.dart';

class UserStoryAvatar extends ConsumerWidget {
  final String userId;
  final String? profilePicUrl;
  final String? username;
  final double size;
  final bool showPresence;
  final bool isClickable;

  const UserStoryAvatar({
    super.key,
    required this.userId,
    this.profilePicUrl,
    this.username,
    this.size = 40,
    this.showPresence = false,
    this.isClickable = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Story state from storyFeedProvider
    final storyState = ref.watch(storyFeedProvider);
    final group = storyState.userGroups.where((g) => g.user.id == userId).firstOrNull;
    final hasStory = group != null && group.stories.isNotEmpty;
    final hasUnseen = group != null && group.hasUnseen;

    // 2. Presence state from presenceProvider if showPresence is true
    final isOnline = showPresence
        ? ref.watch(presenceProvider.select((state) => state.onlineUsers[userId] ?? false))
        : false;

    // 3. Avatar child (CachedNetworkImage or letter placeholder)
    final avatarChild = (profilePicUrl != null && profilePicUrl!.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: profilePicUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFFDBDBDB)),
            errorWidget: (_, __, ___) => _defaultAvatar(username, size),
          )
        : _defaultAvatar(username, size);

    // 4. Main avatar wrapper (StoryRing if user has story, else regular circle clip)
    Widget mainAvatar;
    if (hasStory) {
      mainAvatar = StoryRing(
        size: size,
        hasUnseen: hasUnseen,
        child: avatarChild,
      );
    } else {
      mainAvatar = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: ClipOval(child: avatarChild),
      );
    }

    // 5. Wrap in tap handler if clickable and user has active story
    if (isClickable && hasStory) {
      mainAvatar = GestureDetector(
        onTap: () {
          context.push('/story/$userId');
        },
        child: mainAvatar,
      );
    }

    // 6. Overlap presence dot if online
    if (isOnline) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final dotSize = size * 0.25 > 14.0 ? 14.0 : (size * 0.25 < 10.0 ? 10.0 : size * 0.25);
      final borderSize = dotSize * 0.15 > 2.0 ? 2.0 : (dotSize * 0.15 < 1.5 ? 1.5 : dotSize * 0.15);

      return Stack(
        clipBehavior: Clip.none,
        children: [
          mainAvatar,
          Positioned(
            right: hasStory ? 1 : 0,
            bottom: hasStory ? 1 : 0,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: const Color(0xFF00C853), // Instagram green active dot
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.black : Colors.white,
                  width: borderSize,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return mainAvatar;
  }

  Widget _defaultAvatar(String? name, double avatarSize) {
    final displayLetter = (name != null && name.isNotEmpty)
        ? name.substring(0, 1).toUpperCase()
        : '?';
    return Container(
      color: const Color(0xFFDBDBDB),
      alignment: Alignment.center,
      child: Text(
        displayLetter,
        style: TextStyle(
          fontSize: avatarSize * 0.35,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
          fontFamily: 'Instagram-Sans',
        ),
      ),
    );
  }
}
