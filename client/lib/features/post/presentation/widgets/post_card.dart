// lib/features/post/presentation/widgets/post_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../data/models/post_model.dart';
import '../providers/feed_provider.dart';

class PostCard extends ConsumerStatefulWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  // For image carousel
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  // For double-tap like animation
  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnim;
  late Animation<double> _heartOpacityAnim;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();

    // Heart animation setup
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _heartScaleAnim = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_heartAnimController);

    _heartOpacityAnim = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 30),
    ]).animate(_heartAnimController);

    _heartAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHeart = false);
        _heartAnimController.reset();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heartAnimController.dispose();
    super.dispose();
  }

  // ─── DOUBLE TAP LIKE ──────────────────────────────────────
  void _handleDoubleTap() {
    // Only like if not already liked
    if (!widget.post.isLiked) {
      ref.read(feedProvider.notifier).toggleLike(widget.post.id);
    }

    // Show heart animation regardless
    setState(() => _showHeart = true);
    _heartAnimController.forward();
  }

  // ─── TOGGLE LIKE ─────────────────────────────────────────
  void _handleLikeTap() {
    ref.read(feedProvider.notifier).toggleLike(widget.post.id);
  }

  // ─── TOGGLE SAVE ─────────────────────────────────────────
  void _handleSaveTap() {
    ref.read(feedProvider.notifier).toggleSave(widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    // Watch this specific post from feed state
    final feedState = ref.watch(feedProvider);
    final post = feedState.posts.firstWhere(
      (p) => p.id == widget.post.id,
      orElse: () => widget.post,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── POST HEADER ──────────────────────────────────
        _buildHeader(context, post),

        // ─── POST IMAGES (carousel) ───────────────────────
        _buildImageCarousel(context, post),

        // ─── ACTION BUTTONS ───────────────────────────────
        _buildActionButtons(post),

        // ─── LIKES COUNT ──────────────────────────────────
        _buildLikesCount(post),

        // ─── CAPTION ──────────────────────────────────────
        if (post.caption != null && post.caption!.isNotEmpty)
          _buildCaption(context, post),

        // ─── COMMENTS PREVIEW ────────────────────────────
        _buildCommentsPreview(context, post),

        // ─── TIMESTAMP ───────────────────────────────────
        _buildTimestamp(post),

        const SizedBox(height: 4),
      ],
    );
  }

  // ─── HEADER ──────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, PostModel post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () {
              if (post.user != null) {
                context.push('/profile/${post.user!.username}');
              }
            },
            child: _buildAvatar(post.user?.profilePicUrl, 36),
          ),

          const SizedBox(width: 10),

          // Username + location
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (post.user != null) {
                  context.push('/profile/${post.user!.username}');
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        post.user?.username ?? 'unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (post.user?.isVerified == true) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                  if (post.location != null && post.location!.isNotEmpty)
                    Text(
                      post.location!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Three dots menu
          IconButton(
            onPressed: () => _showPostOptions(context, post),
            icon: const Icon(Icons.more_horiz, color: AppColors.textPrimary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ─── IMAGE CAROUSEL ───────────────────────────────────────
  Widget _buildImageCarousel(BuildContext context, PostModel post) {
    if (post.media.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        // Images
        GestureDetector(
          onDoubleTap: _handleDoubleTap,
          child: SizedBox(
            height: 400,
            child: post.isCarousel
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: post.media.length,
                    onPageChanged: (index) {
                      setState(() => _currentImageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return _buildMediaItem(post.media[index]);
                    },
                  )
                : _buildMediaItem(post.media.first),
          ),
        ),

        // Double-tap heart animation
        if (_showHeart)
          Positioned.fill(
            child: Center(
              child: AnimatedBuilder(
                animation: _heartAnimController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _heartOpacityAnim.value,
                    child: Transform.scale(
                      scale: _heartScaleAnim.value,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 100,
                        shadows: [
                          Shadow(blurRadius: 20, color: Colors.black54),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // Carousel dots indicator
        if (post.isCarousel)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                post.media.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentImageIndex == index ? 8 : 6,
                  height: _currentImageIndex == index ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),

        // Multiple images indicator (top right)
        if (post.isCarousel)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
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
    );
  }

  Widget _buildMediaItem(PostMediaModel media) {
    return CachedNetworkImage(
      imageUrl: media.feedUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (context, url) => Container(
        color: AppColors.border,
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppColors.border,
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─── ACTION BUTTONS ───────────────────────────────────────
  Widget _buildActionButtons(PostModel post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          // Like button
          _ActionButton(
            icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
            color: post.isLiked ? AppColors.secondary : AppColors.textPrimary,
            onTap: _handleLikeTap,
          ),

          // Comment button
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            onTap: () => context.push('/post/${post.id}'),
          ),

          // Share button
          _ActionButton(
            icon: Icons.send_outlined,
            onTap: () {
              // Share feature - Day 25
            },
          ),

          const Spacer(),

          // Save button
          _ActionButton(
            icon: post.isSaved ? Icons.bookmark : Icons.bookmark_border,
            color: post.isSaved ? AppColors.textPrimary : AppColors.textPrimary,
            onTap: _handleSaveTap,
          ),
        ],
      ),
    );
  }

  // ─── LIKES COUNT ─────────────────────────────────────────
  Widget _buildLikesCount(PostModel post) {
    if (post.likeCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => context.push('/post/${post.id}/likes'),
        child: Text(
          '${_formatCount(post.likeCount)} ${post.likeCount == 1 ? 'like' : 'likes'}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ─── CAPTION ─────────────────────────────────────────────
  Widget _buildCaption(BuildContext context, PostModel post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: _CaptionText(
        username: post.user?.username ?? '',
        caption: post.caption ?? '',
        hashtags: post.hashtags,
      ),
    );
  }

  // ─── COMMENTS PREVIEW ────────────────────────────────────
  Widget _buildCommentsPreview(BuildContext context, PostModel post) {
    if (post.commentCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: GestureDetector(
        onTap: () => context.push('/post/${post.id}'),
        child: Text(
          post.commentCount == 1
              ? 'View 1 comment'
              : 'View all ${_formatCount(post.commentCount)} comments',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ),
    );
  }

  // ─── TIMESTAMP ───────────────────────────────────────────
  Widget _buildTimestamp(PostModel post) {
    final timeText = post.createdAt != null
        ? timeago.format(post.createdAt!, locale: 'en_short')
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        timeText.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ─── AVATAR BUILDER ───────────────────────────────────────
  Widget _buildAvatar(String? imageUrl, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: ClipOval(
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: AppColors.border),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.border,
                  child: const Icon(
                    Icons.person,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : Container(
                color: AppColors.border,
                child: const Icon(Icons.person, color: AppColors.textSecondary),
              ),
      ),
    );
  }

  // ─── POST OPTIONS MENU ────────────────────────────────────
  void _showPostOptions(BuildContext context, PostModel post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            if (post.isOwnPost) ...[
              _OptionTile(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: () {
                  Navigator.pop(ctx);
                  // Navigate to edit post
                },
              ),
              _OptionTile(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: AppColors.secondary,
                onTap: () {
                  Navigator.pop(ctx);
                  // Confirm and delete
                },
              ),
              _OptionTile(
                icon: Icons.archive_outlined,
                label: 'Archive',
                onTap: () => Navigator.pop(ctx),
              ),
            ] else ...[
              _OptionTile(
                icon: Icons.report_outlined,
                label: 'Report',
                color: AppColors.secondary,
                onTap: () => Navigator.pop(ctx),
              ),
              _OptionTile(
                icon: Icons.person_remove_outlined,
                label: 'Unfollow',
                onTap: () => Navigator.pop(ctx),
              ),
            ],

            _OptionTile(
              icon: Icons.link,
              label: 'Copy link',
              onTap: () => Navigator.pop(ctx),
            ),
            _OptionTile(
              icon: Icons.share_outlined,
              label: 'Share to...',
              onTap: () => Navigator.pop(ctx),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

// ─── CAPTION TEXT (handles hashtags) ────────────────────────
class _CaptionText extends StatefulWidget {
  final String username;
  final String caption;
  final List<String> hashtags;

  const _CaptionText({
    required this.username,
    required this.caption,
    required this.hashtags,
  });

  @override
  State<_CaptionText> createState() => _CaptionTextState();
}

class _CaptionTextState extends State<_CaptionText> {
  bool _expanded = false;
  static const int _maxLines = 2;

  @override
  Widget build(BuildContext context) {
    final fullText = widget.caption;
    final isLong = fullText.length > 100;

    return GestureDetector(
      onTap: () {
        if (isLong) setState(() => _expanded = !_expanded);
      },
      child: RichText(
        maxLines: _expanded ? null : _maxLines,
        overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
          children: [
            // Username bold
            TextSpan(
              text: '${widget.username} ',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            // Caption text with hashtags colored
            ..._buildCaptionSpans(fullText, context),
            // "more" button
            if (isLong && !_expanded)
              const TextSpan(
                text: ' more',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

 // In post_card.dart, update _buildCaptionSpans method:
// FIND this method and REPLACE the hashtag TextSpan:

List<TextSpan> _buildCaptionSpans(
  String text,
  BuildContext context,  // ADD context parameter
) {
  final spans = <TextSpan>[];
  final parts = text.split(RegExp(r'(#\w+)'));

  for (final part in parts) {
    if (part.startsWith('#')) {
      final tag = part.substring(1); // Remove #
      spans.add(TextSpan(
        text: part,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            // Navigate to hashtag page
            context.push('/hashtag/$tag');
          },
      ));
    } else {
      spans.add(TextSpan(text: part));
    }
  }

  return spans;
}
}

// ─── ACTION BUTTON ──────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.color = AppColors.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 26, color: color),
      ),
    );
  }
}

// ─── OPTION TILE ────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
