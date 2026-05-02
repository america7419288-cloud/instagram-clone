// lib/features/story/presentation/widgets/stories_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/models/story_model.dart';
import '../providers/story_provider.dart';
import 'story_viewer.dart';

class StoriesBar extends ConsumerWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyState = ref.watch(storyFeedProvider);
    final currentUser = ref.watch(currentUserProvider);

    // Still loading
    if (storyState.isLoading) {
      return const _StoriesBarSkeleton();
    }

    // No stories at all
    if (storyState.isEmpty && currentUser == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        children: [
          // ─── YOUR STORY ─────────────────────────────────
          if (currentUser != null)
            _YourStoryItem(
  profilePicUrl: currentUser.profilePicUrl,
  username: currentUser.username,
  hasStory: storyState.userGroups.any((g) => g.isOwn),
  onTap: () {
    final ownGroup = storyState.userGroups
        .where((g) => g.isOwn)
        .firstOrNull;

    if (ownGroup != null && ownGroup.stories.isNotEmpty) {
      // View own stories
      _openStoryViewer(
        context,
        ref,
        storyState.userGroups,
        storyState.userGroups.indexOf(ownGroup),
      );
    } else {
      // ⭐ Open story creator instead of snackbar
      context.push('/story-create');
    }
  },
),


          // ─── OTHER USERS' STORIES ────────────────────────
          ...storyState.userGroups
              .where((g) => !g.isOwn)
              .map((group) => _StoryItem(
                    group: group,
                    onTap: () {
                      final index =
                          storyState.userGroups.indexOf(group);
                      _openStoryViewer(
                          context, ref, storyState.userGroups, index);
                    },
                  )),
        ],
      ),
    );
  }

  // Open full-screen story viewer
  void _openStoryViewer(
    BuildContext context,
    WidgetRef ref,
    List<StoryUserGroup> groups,
    int initialGroupIndex,
  ) {
    // Filter out empty groups and own group (show own at front)
    final nonEmptyGroups =
        groups.where((g) => g.stories.isNotEmpty).toList();

    if (nonEmptyGroups.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return StoryViewer(
            groups: nonEmptyGroups,
            initialGroupIndex: initialGroupIndex
                .clamp(0, nonEmptyGroups.length - 1),
          );
        },
        transitionsBuilder: (context, animation, secondary, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _showCreateStoryPrompt(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '📖 Story creation coming soon!',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ─── YOUR STORY ITEM ────────────────────────────────────────
class _YourStoryItem extends StatelessWidget {
  final String? profilePicUrl;
  final String username;
  final bool hasStory;
  final VoidCallback onTap;

  const _YourStoryItem({
    required this.profilePicUrl,
    required this.username,
    required this.hasStory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with gradient ring (if has story) or + button
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasStory
                        ? AppColors.storyRingGradient
                        : null,
                    color: hasStory
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
                      child: profilePicUrl != null
                          ? CachedNetworkImage(
                              imageUrl: profilePicUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _defaultAvatar(username),
                            )
                          : _defaultAvatar(username),
                    ),
                  ),
                ),

                // + button (bottom right)
                if (!hasStory)
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
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── OTHER USER STORY ITEM ──────────────────────────────────
class _StoryItem extends StatelessWidget {
  final StoryUserGroup group;
  final VoidCallback onTap;

  const _StoryItem({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with gradient or gray ring
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: group.hasUnseen
                    ? AppColors.storyRingGradient
                    : null,
                color: group.hasUnseen
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
                  child: group.user.profilePicUrl != null
                      ? CachedNetworkImage(
                          imageUrl: group.user.profilePicUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _defaultAvatar(),
                        )
                      : _defaultAvatar(),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Username
            SizedBox(
              width: 64,
              child: Text(
                group.user.username,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: group.hasUnseen
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: group.hasUnseen
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    final username = group.user.username;
    return Container(
      color: AppColors.border,
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── SKELETON LOADING ───────────────────────────────────────
class _StoriesBarSkeleton extends StatelessWidget {
  const _StoriesBarSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.border,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 48,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
