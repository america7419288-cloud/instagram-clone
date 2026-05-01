// lib/features/story/presentation/widgets/stories_bar.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Placeholder story data (real stories come on Day 16)
class StoryUser {
  final String id;
  final String username;
  final String? profilePicUrl;
  final bool hasUnseenStory;
  final bool isOwn;

  const StoryUser({
    required this.id,
    required this.username,
    this.profilePicUrl,
    this.hasUnseenStory = false,
    this.isOwn = false,
  });
}

class StoriesBar extends ConsumerWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    // Placeholder stories (will use real API on Day 16)
    final placeholderStories = [
      StoryUser(
        id: 'story_1',
        username: 'travel_shots',
        hasUnseenStory: true,
      ),
      StoryUser(
        id: 'story_2',
        username: 'food_diary',
        hasUnseenStory: true,
      ),
      StoryUser(
        id: 'story_3',
        username: 'city_life',
        hasUnseenStory: false,
      ),
      StoryUser(
        id: 'story_4',
        username: 'sunset_pics',
        hasUnseenStory: true,
      ),
      StoryUser(
        id: 'story_5',
        username: 'adventures',
        hasUnseenStory: false,
      ),
    ];

    return Container(
      height: 95,
      color: AppColors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        children: [
          // Your Story (first item)
          if (currentUser != null)
            _YourStoryItem(user: currentUser),

          const SizedBox(width: 4),

          // Other users' stories
          ...placeholderStories.map(
            (story) => _StoryItem(story: story),
          ),
        ],
      ),
    );
  }
}

// ─── YOUR STORY ITEM ────────────────────────────────────────
class _YourStoryItem extends StatelessWidget {
  final dynamic user;

  const _YourStoryItem({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to create story
        // Will implement on Day 16
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stories coming on Day 16! 📖'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with + button
            Stack(
              children: [
                // Profile picture
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: ClipOval(
                    child: user.profilePicUrl != null
                        ? CachedNetworkImage(
                            imageUrl: user.profilePicUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.border,
                              child: const Icon(
                                Icons.person,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                _defaultAvatar(user.username),
                          )
                        : _defaultAvatar(user.username),
                  ),
                ),

                // Blue + button (bottom right)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Username
            SizedBox(
              width: 64,
              child: Text(
                'Your story',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar(String username) {
    return Container(
      color: AppColors.border,
      child: Center(
        child: Text(
          username.isNotEmpty
              ? username[0].toUpperCase()
              : '?',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── STORY ITEM (other users) ───────────────────────────────
class _StoryItem extends StatelessWidget {
  final StoryUser story;

  const _StoryItem({required this.story});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Will navigate to story viewer on Day 16
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Story ring + avatar
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: story.hasUnseenStory
                    ? AppColors.storyRingGradient
                    : null,
                color: story.hasUnseenStory
                    ? null
                    : AppColors.border,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Container(
                    color: AppColors.border,
                    child: Center(
                      child: Text(
                        story.username.isNotEmpty
                            ? story.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Username
            SizedBox(
              width: 64,
              child: Text(
                story.username,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: story.hasUnseenStory
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: story.hasUnseenStory
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}