// lib/features/post/presentation/widgets/post_card.dart

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/post_model.dart';
import '../providers/feed_provider.dart';
import 'video_player_widget.dart';

class PostCard extends ConsumerStatefulWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with TickerProviderStateMixin {
  // ─── Like animation ──────────────────────────────────
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;

  // ─── Like button bounce ──────────────────────────────
  late AnimationController _likeButtonController;
  late Animation<double> _likeButtonScale;

  // ─── State ───────────────────────────────────────────
  bool _captionExpanded = false;
  late PageController _pageController;
  int _currentPage = 0;
  Offset _tapPosition = Offset.zero;
  bool _showHeartOverlay = false;

  // ─── Optimistic state ─────────────────────────────────
  late bool _isLiked;
  late int _likeCount;
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likesCount;
    _isSaved = widget.post.isSaved;
    _pageController = PageController();

    // Heart overlay animation
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(_heartController);

    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(_heartController);

    // Like button scale
    _likeButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeButtonScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _likeButtonController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    _likeButtonController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ─── Like ─────────────────────────────────────────────
  Future<void> _handleLike() async {
    HapticFeedback.lightImpact();
    final wasLiked = _isLiked;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    _likeButtonController.forward(from: 0);

    try {
      await ref.read(feedProvider.notifier).toggleLike(widget.post.id);
    } catch (_) {

      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount += wasLiked ? 1 : -1;
        });
      }
    }
  }

  // ─── Double tap to like ───────────────────────────────
  void _handleDoubleTap(Offset position) {
    _tapPosition = position;
    if (!_isLiked) _handleLike();

    setState(() => _showHeartOverlay = true);
    _heartController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeartOverlay = false);
    });
  }

  // ─── Save ─────────────────────────────────────────────
  Future<void> _handleSave() async {
    HapticFeedback.lightImpact();
    final wasSaved = _isSaved;
    setState(() => _isSaved = !_isSaved);
    try {
      if (wasSaved) {
        await ref.read(feedProvider.notifier).unsavePost(widget.post.id);
      } else {
        await ref.read(feedProvider.notifier).savePost(widget.post.id);
      }
    } catch (_) {
      if (mounted) setState(() => _isSaved = wasSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(isDark),
        _buildMediaSection(isDark),
        _buildActions(isDark),
        _buildLikeCount(isDark),
        _buildCaption(isDark),
        _buildCommentPreview(isDark),
        _buildTimestamp(isDark),
        const SizedBox(height: 4),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () =>
                context.push('/profile/${widget.post.username}'),
            child: CircleAvatar(
              radius: 18,
              backgroundColor:
                  isDark ? AppColors.darkDivider : AppColors.divider,
              backgroundImage: widget.post.userAvatar != null
                  ? CachedNetworkImageProvider(widget.post.userAvatar!)
                  : null,
              child: widget.post.userAvatar == null
                  ? Icon(
                      Icons.person,
                      size: 18,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),

          // Username + location
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  context.push('/profile/${widget.post.username}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.post.username,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (widget.post.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: AppColors.verified,
                        ),
                      ],
                    ],
                  ),
                  if (widget.post.location != null &&
                      widget.post.location!.isNotEmpty)
                    Text(
                      widget.post.location!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),

          // More options
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: isDark
                  ? AppColors.darkIconPrimary
                  : AppColors.iconPrimary,
            ),
            onPressed: () => _showPostOptions(context, isDark),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // MEDIA SECTION (image or video carousel)
  // ─────────────────────────────────────────────────────
  Widget _buildMediaSection(bool isDark) {
    final size = MediaQuery.of(context).size.width;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // ─── PageView carousel ─────────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: widget.post.mediaFiles.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final media = widget.post.mediaFiles[index];

              if (media.isVideo) {
                // ─── VIDEO ────────────────────────────────
                return VideoPlayerWidget(
                  videoUrl: media.url,
                  thumbnailUrl: media.thumbnailUrl,
                  duration: media.duration,
                  autoPlay: index == _currentPage,
                  showControls: true,
                  looping: true,
                  fit: BoxFit.cover,
                );
              } else {
                // ─── IMAGE ────────────────────────────────
                return GestureDetector(
                  onDoubleTapDown: (d) =>
                      _handleDoubleTap(d.localPosition),
                  onDoubleTap: () {}, // required for onDoubleTapDown
                  child: CachedNetworkImage(
                    imageUrl: media.url,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    placeholder: (_, __) => Container(
                      color: isDark
                          ? AppColors.darkShimmerBase
                          : AppColors.shimmerBase,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.divider,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        size: 40,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                );
              }
            },
          ),

          // ─── Double-tap heart overlay (images only) ────
          if (_showHeartOverlay)
            Positioned(
              left: _tapPosition.dx - 45,
              top: _tapPosition.dy - 45,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _heartController,
                  builder: (_, __) => Opacity(
                    opacity: _heartOpacity.value,
                    child: Transform.scale(
                      scale: _heartScale.value,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 90,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ─── Page indicator dots ───────────────────────
          if (widget.post.mediaFiles.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.post.mediaFiles.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _currentPage == i ? 6 : 4,
                    height: _currentPage == i ? 6 : 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == i
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),

          // ─── Multi-image icon (top right) ─────────────
          if (widget.post.hasMultiple &&
              !widget.post.mediaFiles[_currentPage].isVideo)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.collections,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // ACTION BUTTONS
  // ─────────────────────────────────────────────────────
  Widget _buildActions(bool isDark) {
    final iconColor =
        isDark ? AppColors.darkIconPrimary : AppColors.iconPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          // ─── Like ──────────────────────────────────────
          AnimatedBuilder(
            animation: _likeButtonController,
            builder: (_, child) => Transform.scale(
              scale: _likeButtonScale.value,
              child: child,
            ),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: Icon(
                  _isLiked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  key: ValueKey(_isLiked),
                  color: _isLiked ? AppColors.like : iconColor,
                  size: 26,
                ),
              ),
              onPressed: _handleLike,
              padding: const EdgeInsets.all(4),
            ),
          ),

          // ─── Comment ───────────────────────────────────
          IconButton(
            icon: Icon(
              Icons.chat_bubble_outline,
              color: iconColor,
              size: 24,
            ),
            onPressed: () =>
                context.push('/post/${widget.post.id}'),
            padding: const EdgeInsets.all(4),
          ),

          // ─── Share ─────────────────────────────────────
          IconButton(
            icon: Icon(
              Icons.near_me_outlined,
              color: iconColor,
              size: 24,
            ),
            onPressed: () {},
            padding: const EdgeInsets.all(4),
          ),

          const Spacer(),

          // ─── Save ──────────────────────────────────────
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: child,
              ),
              child: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                key: ValueKey(_isSaved),
                color: iconColor,
                size: 24,
              ),
            ),
            onPressed: _handleSave,
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // LIKE COUNT
  // ─────────────────────────────────────────────────────
  Widget _buildLikeCount(bool isDark) {
    if (_likeCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GestureDetector(
        onTap: () => context.push('/post/${widget.post.id}/likes'),
        child: Text(
          _likeCount == 1
              ? '1 like'
              : '${_formatCount(_likeCount)} likes',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // CAPTION
  // ─────────────────────────────────────────────────────
  Widget _buildCaption(bool isDark) {
    final caption = widget.post.caption;
    if (caption == null || caption.isEmpty) {
      return const SizedBox.shrink();
    }

    final isLong = caption.length > 125;
    final displayText = isLong && !_captionExpanded
        ? '${caption.substring(0, 125)}...'
        : caption;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: GestureDetector(
        onTap: isLong && !_captionExpanded
            ? () => setState(() => _captionExpanded = true)
            : null,
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.textPrimary,
            ),
            children: [
              // Username
              TextSpan(
                text: '${widget.post.username} ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              // Caption text
              TextSpan(text: displayText),
              // "more" link
              if (isLong && !_captionExpanded)
                TextSpan(
                  text: ' more',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // COMMENT PREVIEW
  // ─────────────────────────────────────────────────────
  Widget _buildCommentPreview(bool isDark) {
    if (widget.post.commentsCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
      child: GestureDetector(
        onTap: () => context.push('/post/${widget.post.id}'),
        child: Text(
          'View all ${widget.post.commentsCount} comments',
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // TIMESTAMP
  // ─────────────────────────────────────────────────────
  Widget _buildTimestamp(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Text(
        timeago.format(widget.post.createdAt).toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: isDark
              ? AppColors.darkTextTertiary
              : AppColors.textTertiary,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // POST OPTIONS SHEET
  // ─────────────────────────────────────────────────────
  void _showPostOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkDivider
                      : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copy link'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Report',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
