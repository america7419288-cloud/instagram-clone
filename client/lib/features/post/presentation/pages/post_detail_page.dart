// lib/features/post/presentation/pages/post_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/router/navigation_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/post_service.dart';
import 'package:instagram_clinet/features/post/presentation/providers/feed_provider.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../widgets/video_player_widget.dart';


class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final ScrollController _scrollController = ScrollController();
  PostModel? _post;
  bool _isLoadingPost = true;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    try {
      final post = await PostService().getPost(widget.postId);
      if (mounted) {
        setState(() {
          _post = post;
          _isLoadingPost = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPost = false);
      }
    }
  }

  void _toggleLike() {
    if (_post != null) {
      ref.read(feedProvider.notifier).toggleLike(_post!.id);
      setState(() {
        _post = _post!.copyWith(
          isLiked: !_post!.isLiked,
          likeCount: _post!.isLiked
              ? _post!.likeCount - 1
              : _post!.likeCount + 1,
        );
      });
    }
  }

  void _toggleSave() {
    if (_post != null) {
      ref.read(feedProvider.notifier).toggleSave(_post!.id);
      setState(() {
        _post = _post!.copyWith(isSaved: !_post!.isSaved);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: CupertinoNavigationBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[900]! : Colors.grey[300]!,
            width: 0.5,
          ),
        ),
        leading: BouncyTap(
          onTap: () => context.pop(),
          child: const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Icon(CupertinoIcons.chevron_back, color: AppColors.primary),
          ),
        ),
        middle: const Text(
          'Posts',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            fontFamily: 'SF Pro Text',
          ),
        ),
      ),
      body: _isLoadingPost
          ? const Center(child: CupertinoActivityIndicator())
          : _post == null
              ? const Center(child: Text('Post not found'))
              : SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPostHeader(_post!),
                      _buildImageSection(_post!),
                      _buildPostActions(_post!),
                      _buildPostDetails(_post!),
                      const SizedBox(height: 100), // Bottom spacing
                    ],
                  ),
                ),
    );
  }

  Widget _buildPostHeader(PostModel post) {
    final author = post.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          BouncyTap(
            onTap: () {
              if (author != null) {
                context.pushIfNotCurrent('/profile/${author.username}');
              }
            },
            child: _buildAvatar(author?.profilePicUrl, 32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BouncyTap(
                  onTap: () {
                    if (author != null) {
                      context.pushIfNotCurrent('/profile/${author.username}');
                    }
                  },
                  child: Text(
                    author?.username ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (post.location != null)
                  Text(
                    post.location!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          BouncyTap(
            onTap: () => _showPostOptions(),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                LucideIcons.eclipse,
                size: 24,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(PostModel post) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          post.isCarousel
              ? PageView.builder(
                  itemCount: post.media.length,
                  onPageChanged: (i) => setState(() => _currentImageIndex = i),
                  itemBuilder: (_, i) => _buildMediaItem(post.media[i]),
                )
              : _buildMediaItem(post.media.first),
          if (post.isCarousel)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${post.media.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(PostMediaModel media) {
    if (media.isVideo) {
      return VideoPlayerWidget(videoUrl: media.url, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: media.feedUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (_, __) => Container(color: AppColors.border),
    );
  }

  Widget _buildPostActions(PostModel post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          BouncyTap(
            onTap: _toggleLike,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                LucideIcons.heart,
                color: post.isLiked ? Colors.red : (isDark ? Colors.white : Colors.black),
                size: 26,
                fill: post.isLiked ? 1.0 : 0.0,
              ),
            ),
          ),
          BouncyTap(
            onTap: () => context.push('/post/${post.id}/comments', extra: post),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                LucideIcons.message_circle,
                size: 24,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          BouncyTap(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                LucideIcons.send,
                size: 24,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const Spacer(),
          if (post.isCarousel) _buildCarouselDots(post.media.length),
          const Spacer(),
          BouncyTap(
            onTap: _toggleSave,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                LucideIcons.bookmark,
                size: 24,
                color: isDark ? Colors.white : Colors.black,
                fill: post.isSaved ? 1.0 : 0.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselDots(int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (i) => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentImageIndex == i
                ? const Color(0xFF0095F6)
                : Colors.grey.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildPostDetails(PostModel post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.likeCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${post.likeCount} likes',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          if (post.caption != null && post.caption!.isNotEmpty)
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: '${post.user?.username ?? ''} ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: post.caption!),
                ],
              ),
            ),
          if (post.commentCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: BouncyTap(
                onTap: () => context.push('/post/${post.id}/comments', extra: post),
                child: Text(
                  'View all ${post.commentCount} comments',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              timeago.format(post.createdAt).toUpperCase(),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPostOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Share to...'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Copy Link'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Report'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.border),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
          : null,
    );
  }
}
