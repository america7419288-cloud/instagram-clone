import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story_model.dart';
import 'story_progress_bar.dart';

class StoryHeader extends StatelessWidget {
  final StoryUserModel user;
  final int currentStoryIndex;
  final Animation<double> progressAnimation;
  final VoidCallback onMoreTapped;
  final VoidCallback onCloseTapped;
  final bool isOwner;

  const StoryHeader({
    super.key,
    required this.user,
    required this.currentStoryIndex,
    required this.progressAnimation,
    required this.onMoreTapped,
    required this.onCloseTapped,
    this.isOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    final story = user.stories[currentStoryIndex];
    final timeAgo = _formatTimeAgo(story.createdAt);

    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Progress bars ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            child: StoryProgressBar(
              count: user.stories.length,
              currentIndex: currentStoryIndex,
              progressAnimation: progressAnimation,
            ),
          ),

          // ── User info row ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 8, 0),
            child: Row(
              children: [
                // Avatar
                _StoryAvatar(
                  avatarUrl: user.avatarUrl,
                  isCloseFriend: user.isCloseFriend,
                ),
                const SizedBox(width: 10),

                // Username + time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            user.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (user.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // Mute / More
                _HeaderIconButton(
                  icon: Icons.volume_up_rounded,
                  onTap: () {}, // TODO: mute
                ),
                const SizedBox(width: 4),
                _HeaderIconButton(
                  icon: Icons.more_horiz,
                  onTap: onMoreTapped,
                ),
                const SizedBox(width: 4),
                _HeaderIconButton(
                  icon: Icons.close_rounded,
                  onTap: onCloseTapped,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StoryAvatar extends StatelessWidget {
  final String avatarUrl;
  final bool isCloseFriend;

  const _StoryAvatar({
    required this.avatarUrl,
    required this.isCloseFriend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isCloseFriend
              ? const Color(0xFF4CAF50)
              : Colors.white.withOpacity(0.9),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => const CircleAvatar(
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
          shadows: const [
            Shadow(
              color: Colors.black38,
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
