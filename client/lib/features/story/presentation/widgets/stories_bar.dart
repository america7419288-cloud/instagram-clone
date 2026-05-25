// lib/features/story/presentation/widgets/stories_bar.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/router/app_router.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/story_ring.dart';
import '../../data/models/story_model.dart';
import '../providers/story_provider.dart';

class StoriesBar extends ConsumerWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyState = ref.watch(storyFeedProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Container(
      height: 124,
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        children: [
          if (currentUser != null)
            _YourStoryItem(
              userId: currentUser.id,
              profilePicUrl: currentUser.profilePicUrl,
              hasStory: storyState.userGroups.any((g) => g.isOwn),
              hasUnseen: storyState.userGroups.any((g) => g.isOwn && g.hasUnseen),
              onTap: (rect) {
                final ownGroup = storyState.userGroups.where((g) => g.isOwn).firstOrNull;
                if (ownGroup != null && ownGroup.stories.isNotEmpty) {
                  ref.read(isSwipeDismissingProvider.notifier).setSwipeDismissing(false);
                  context.push('/story/${currentUser.id}', extra: {'originRect': rect});
                } else {
                  context.push(AppRoutes.createStory);
                }
              },
            ),
          ...storyState.userGroups.where((g) => !g.isOwn).map(
            (group) => _StoryItem(
              group: group,
              onTap: (rect) {
                ref.read(isSwipeDismissingProvider.notifier).setSwipeDismissing(false);
                context.push('/story/${group.user.id}', extra: {'originRect': rect});
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _YourStoryItem extends StatelessWidget {
  final String userId;
  final String? profilePicUrl;
  final bool hasStory;
  final bool hasUnseen;
  final ValueChanged<Rect> onTap;

  const _YourStoryItem({
    required this.userId,
    required this.profilePicUrl,
    required this.hasStory,
    required this.hasUnseen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return BouncyTap(
      onTap: () {
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;
          final rect = Rect.fromLTWH(
            position.dx + (size.width - 78) / 2,
            position.dy,
            78,
            78,
          );
          onTap(rect);
        } else {
          onTap(Rect.zero);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: Column(
          children: [
            Stack(
              children: [
                StoryRing(
                  size: 78, // Increased from 68
                  hasUnseen: hasUnseen,
                  child: (profilePicUrl != null && profilePicUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: profilePicUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: const Color(0xFFDBDBDB)),
                        )
                      : Container(
                          color: const Color(0xFFDBDBDB),
                          child: const Icon(LucideIcons.user, color: Colors.white, size: 24),
                        ),
                ),
                if (!hasStory)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0095F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                      ),
                      child: const Icon(LucideIcons.plus, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your story',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                fontFamily: 'Instagram-Sans',
                color: isDark ? Colors.white70 : const Color(0xFF262626),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final StoryFeedModel group;
  final ValueChanged<Rect> onTap;

  const _StoryItem({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return BouncyTap(
      onTap: () {
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;
          final rect = Rect.fromLTWH(
            position.dx + (size.width - 78) / 2,
            position.dy,
            78,
            78,
          );
          onTap(rect);
        } else {
          onTap(Rect.zero);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: Column(
          children: [
            StoryRing(
              size: 78, // Increased from 68
              hasUnseen: group.hasUnseen,
              child: (group.user.profilePicUrl != null && group.user.profilePicUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: group.user.profilePicUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: const Color(0xFFDBDBDB)),
                    )
                  : Container(
                      color: const Color(0xFFDBDBDB),
                      child: const Icon(LucideIcons.user, color: Colors.white, size: 24),
                    ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 80,
              child: Text(
                group.user.username,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Instagram-Sans',
                  color: isDark ? Colors.white : const Color(0xFF262626),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
