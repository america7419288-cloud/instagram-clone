// lib/features/profile/widgets/profile_posts_grid.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import 'package:instagram_client/features/post/data/models/post_model.dart';
import 'package:instagram_client/features/post/presentation/providers/post_provider.dart';
import 'package:instagram_client/features/post/presentation/pages/post_detail_page.dart';
import 'package:instagram_client/features/post/presentation/pages/edit_post_screen.dart';
import 'package:instagram_client/core/theme/ios_colors.dart';
import 'package:instagram_client/features/profile/data/models/profile_model.dart';
import 'post_options_menu.dart';

class ProfilePostsGrid extends StatefulWidget {
  final String userId;
  final bool isOwnProfile;
  final List<ProfilePostModel> initialPosts;

  const ProfilePostsGrid({
    super.key,
    required this.userId,
    required this.isOwnProfile,
    required this.initialPosts,
  });

  @override
  State<ProfilePostsGrid> createState() => _ProfilePostsGridState();
}

class _ProfilePostsGridState extends State<ProfilePostsGrid> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer(
      builder: (ctx, ref, _) {
        final provider = ref.watch(postProvider);

        if (!_initialized) {
          _initialized = true;
          // Defer population to safe frame callback
          Future.microtask(() {
            ref.read(postProvider.notifier).setPosts(
              widget.initialPosts.map((p) => PostModel.fromProfilePost(p)).toList(),
            );
          });
        }

        final pinned = provider.pinnedPosts;
        final regular = provider.regularPosts;
        final List<PostModel> allPosts = [...pinned, ...regular];

        if (allPosts.isEmpty && provider.posts.isEmpty) {
          return _EmptyPostsState(
            isOwn: widget.isOwnProfile,
            isDark: isDark,
          );
        }

        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1.5,
            mainAxisSpacing: 1.5,
          ),
          itemCount: allPosts.length,
          itemBuilder: (ctx, i) {
            final post = allPosts[i];
            return _ProfilePostCell(
              post: post,
              isOwn: widget.isOwnProfile,
              isDark: isDark,
              onLongPress: () => _showPostOptions(context, post, ref),
              onTap: () => _openPost(context, post, i, allPosts),
            );
          },
        );
      },
    );
  }

  void _showPostOptions(BuildContext context, PostModel post, WidgetRef ref) {
    if (!widget.isOwnProfile) return;
    final provider = ref.read(postProvider.notifier);

    PostOptionsMenu.show(
      context: context,
      post: post,
      isOwnPost: widget.isOwnProfile,
      onAction: (action) => _handleAction(context, action, post, provider),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    PostAction action,
    PostModel post,
    PostNotifier provider,
  ) async {
    switch (action) {
      case PostAction.pin:
      case PostAction.unpin:
        await provider.togglePin(post.id);
        if (provider.error != null) {
          _showFeedback(context, provider.error!, icon: CupertinoIcons.info);
          provider.clearError();
        } else {
          _showFeedback(
            context,
            post.isPinned ? 'Post unpinned' : 'Post pinned to profile',
            icon: Icons.push_pin,
          );
        }
        break;

      case PostAction.archive:
      case PostAction.unarchive:
        await provider.toggleArchive(post.id);
        _showFeedback(
          context,
          post.isArchived ? 'Post unarchived' : 'Post archived',
          icon: CupertinoIcons.archivebox,
        );
        break;

      case PostAction.edit:
        if (!context.mounted) return;
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => EditPostScreen(post: post),
          ),
        );
        break;

      case PostAction.hideLikes:
      case PostAction.showLikes:
        await provider.toggleHideLikes(post.id);
        _showFeedback(
          context,
          post.hideLikesCount
            ? 'Like count visible'
            : 'Like count hidden',
          icon: CupertinoIcons.eye_slash,
        );
        break;

      case PostAction.turnOffComments:
      case PostAction.turnOnComments:
        await provider.toggleComments(post.id);
        _showFeedback(
          context,
          post.commentsDisabled
            ? 'Commenting turned on'
            : 'Commenting turned off',
          icon: CupertinoIcons.chat_bubble,
        );
        break;

      case PostAction.editAudience:
        if (!context.mounted) return;
        _showAudienceSheet(context, post, provider);
        break;

      case PostAction.copyLink:
        await Clipboard.setData(
          ClipboardData(text: 'https://instagram.com/p/${post.id}'),
        );
        _showFeedback(context, 'Link copied', icon: CupertinoIcons.link);
        break;

      case PostAction.delete:
        await provider.deletePost(post.id);
        break;

      default:
        break;
    }
  }

  void _showAudienceSheet(
    BuildContext context,
    PostModel post,
    PostNotifier provider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditAudienceSheet(
        currentAudience: post.audience,
        onSelect: (audience) {
          provider.updateAudience(post.id, audience);
          _showFeedback(
            context,
            'Audience updated',
            icon: CupertinoIcons.person_2,
          );
        },
      ),
    );
  }

  void _showFeedback(
    BuildContext context,
    String message, {
    required IconData icon,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              message,
              style: const TextStyle(
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.black87,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  void _openPost(
    BuildContext context,
    PostModel post,
    int index,
    List<PostModel> posts,
  ) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => PostDetailPage(
          postId: post.id,
        ),
      ),
    );
  }
}

// ── Post Cell ──
class _ProfilePostCell extends StatefulWidget {
  final PostModel post;
  final bool isOwn;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ProfilePostCell({
    required this.post,
    required this.isOwn,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_ProfilePostCell> createState() => _ProfilePostCellState();
}

class _ProfilePostCellState extends State<_ProfilePostCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _longPressCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _longPressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _longPressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _longPressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (_) {
        _longPressCtrl.forward();
        HapticFeedback.mediumImpact();
      },
      onLongPressEnd: (_) {
        _longPressCtrl.reverse();
        widget.onLongPress();
      },
      onLongPressCancel: () => _longPressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            if (post.mediaUrls.isNotEmpty)
              CachedNetworkImage(
                imageUrl: post.mediaUrls.first,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: widget.isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFE0E0E0),
                ),
              ),

            // Pin indicator
            if (post.isPinned)
              Positioned(
                top: 6,
                left: 6,
                child: _PostBadge(
                  icon: Icons.push_pin,
                  color: Colors.white,
                ),
              ),

            // Carousel indicator
            if (post.type == PostType.carousel)
              Positioned(
                top: 6,
                right: 6,
                child: _PostBadge(
                  icon: CupertinoIcons.square_stack,
                  color: Colors.white,
                ),
              ),

            // Video indicator
            if (post.type == PostType.video)
              Positioned(
                top: 6,
                right: 6,
                child: _PostBadge(
                  icon: CupertinoIcons.play_fill,
                  color: Colors.white,
                ),
              ),

            // Settings indicators (bottom row)
            if (post.hideLikesCount || post.commentsDisabled)
              Positioned(
                bottom: 6,
                right: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (post.hideLikesCount)
                      _PostBadge(
                        icon: CupertinoIcons.eye_slash,
                        color: Colors.white70,
                        small: true,
                      ),
                    if (post.commentsDisabled) ...[
                      const SizedBox(width: 4),
                      _PostBadge(
                        icon: CupertinoIcons.chat_bubble_text,
                        color: Colors.white70,
                        small: true,
                      ),
                    ],
                  ],
                ),
              ),

            // Audience indicator
            if (post.audience != PostAudience.everyone)
              Positioned(
                bottom: 6,
                left: 6,
                child: _AudienceBadge(audience: post.audience),
              ),

            // Archived overlay (dim)
            if (post.isArchived)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PostBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool small;

  const _PostBadge({
    required this.icon,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(small ? 3 : 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        size: small ? 11 : 14,
        color: color,
      ),
    );
  }
}

class _AudienceBadge extends StatelessWidget {
  final PostAudience audience;

  const _AudienceBadge({required this.audience});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (audience) {
      case PostAudience.closeFriends:
        icon = CupertinoIcons.star_fill;
        color = const Color(0xFF58C322);
        break;
      case PostAudience.followers:
        icon = CupertinoIcons.person_2_fill;
        color = Colors.white70;
        break;
      case PostAudience.onlyMe:
        icon = CupertinoIcons.lock_fill;
        color = Colors.white70;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 11, color: color),
    );
  }
}

class _EmptyPostsState extends StatelessWidget {
  final bool isOwn;
  final bool isDark;

  const _EmptyPostsState({
    required this.isOwn,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.camera,
            size: 64,
            color: IosColors.secondary(context),
          ),
          const SizedBox(height: 16),
          Text(
            isOwn ? 'Share photos and videos' : 'No posts yet',
            style: TextStyle(
              color: IosColors.primary(context),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          if (isOwn)
            Text(
              'When you share photos and videos,\nthey\'ll appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: IosColors.secondary(context),
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Edit Audience Sheet ──
class EditAudienceSheet extends StatelessWidget {
  final PostAudience currentAudience;
  final ValueChanged<PostAudience> onSelect;

  const EditAudienceSheet({
    super.key,
    required this.currentAudience,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF48484A) : const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Audience',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 0.5),
          ...PostAudience.values.map((audience) {
            final isSelected = audience == currentAudience;
            return ListTile(
              leading: Icon(
                _audienceIcon(audience),
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              title: Text(
                _audienceTitle(audience),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 15,
                ),
              ),
              trailing: isSelected
                  ? const Icon(CupertinoIcons.checkmark_alt, color: Color(0xFF0095F6))
                  : null,
              onTap: () {
                onSelect(audience);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  IconData _audienceIcon(PostAudience audience) {
    switch (audience) {
      case PostAudience.everyone:
        return CupertinoIcons.globe;
      case PostAudience.followers:
        return CupertinoIcons.person_2;
      case PostAudience.closeFriends:
        return CupertinoIcons.star;
      case PostAudience.onlyMe:
        return CupertinoIcons.lock;
    }
  }

  String _audienceTitle(PostAudience audience) {
    switch (audience) {
      case PostAudience.everyone:
        return 'Everyone';
      case PostAudience.followers:
        return 'Followers';
      case PostAudience.closeFriends:
        return 'Close Friends';
      case PostAudience.onlyMe:
        return 'Only Me';
    }
  }
}
