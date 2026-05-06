// lib/features/post/presentation/widgets/post_card.dart

import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/theme/app_theme.dart';
import '../../data/models/post_model.dart';
import 'package:instagram_clinet/features/post/presentation/providers/feed_provider.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/story_ring.dart';
import 'video_player_widget.dart';

class PostCard extends ConsumerStatefulWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with TickerProviderStateMixin {
  
  // ─── Animations ───────────────────────────────────────
  late AnimationController _heartOverlayController;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;

  late AnimationController _likeBounceController;
  late Animation<double> _likeBounceScale;

  late AnimationController _saveBounceController;
  late Animation<double> _saveBounceScale;

  // ─── State ────────────────────────────────────────────
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isSaved = false;
  bool _showHeartOverlay = false;
  Offset _tapPosition = Offset.zero;
  int _currentPage = 0;
  bool _captionExpanded = false;

  final PageController _pageController = PageController();
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likesCount;
    _isSaved = widget.post.isSaved;

    // Heart overlay (double tap)
    _heartOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700), // 300ms up, 200ms hold, 200ms down
    );
    
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.elasticOut)), 
        weight: 300, // 300ms
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0), 
        weight: 200, // 200ms hold
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), 
        weight: 200, // 200ms fade
      ),
    ]).animate(_heartOverlayController);

    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 100),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 400),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 200),
    ]).animate(_heartOverlayController);

    // Like button bounce
    _likeBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _likeBounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.elasticOut)), 
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), 
        weight: 50,
      ),
    ]).animate(_likeBounceController);

    // Save button bounce
    _saveBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _saveBounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.1), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 30),
    ]).animate(_saveBounceController);
  }

  @override
  void dispose() {
    _heartOverlayController.dispose();
    _likeBounceController.dispose();
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  // ─── Logic ───────────────────────────────────────────
  bool _showParticles = false;

  void _handleLike({bool isDoubleTap = false}) {
    if (!isDoubleTap || (isDoubleTap && !_isLiked)) {
      HapticFeedback.lightImpact();
      _likeBounceController.forward(from: 0);
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      ref.read(feedProvider.notifier).toggleLike(widget.post.id);
    }
    
    if (isDoubleTap) {
      HapticFeedback.mediumImpact();
      setState(() {
        _showHeartOverlay = true;
        _showParticles = true;
      });
      _heartOverlayController.forward(from: 0).then((_) {
        if (mounted) setState(() => _showHeartOverlay = false);
      });
      // Particles reset after a while
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _showParticles = false);
      });
    }
  }

  void _handleSave() {
    HapticFeedback.lightImpact();
    _saveBounceController.forward(from: 0);
    setState(() => _isSaved = !_isSaved);
    if (_isSaved) {
      ref.read(feedProvider.notifier).savePost(widget.post.id);
    } else {
      ref.read(feedProvider.notifier).unsavePost(widget.post.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    
    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          _buildMedia(isDark),
          _buildActionRow(isDark),
          _buildLikes(isDark),
          _buildCaption(isDark),
          _buildCommentsPreview(isDark),
          _buildTimestamp(isDark),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ─── Header (56pt) ────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Avatar with story ring if active
            BouncyTap(
              onTap: () {
                if (widget.post.hasActiveStory) {
                  context.push('/story/${widget.post.userId}');
                } else {
                  context.push('/profile/${widget.post.username}');
                }
              },
              child: StoryRing(
                size: 36,
                hasUnseen: widget.post.hasActiveStory, // Assuming active means unseen for this UI
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.border,
                  backgroundImage: widget.post.userAvatar != null 
                    ? CachedNetworkImageProvider(widget.post.userAvatar!) : null,
                  child: widget.post.userAvatar == null
                    ? Icon(PhosphorIcons.user(), color: Colors.white, size: 16)
                    : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BouncyTap(
                        onTap: () => context.push('/profile/${widget.post.username}'),
                        child: Text(
                          widget.post.username,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF262626),
                          ),
                        ),
                      ),
                      if (widget.post.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill), size: 14, color: const Color(0xFF0095F6)),
                      ],
                    ],
                  ),
                  if (widget.post.location != null)
                    Text(
                      widget.post.location!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : const Color(0xFF262626),
                      ),
                    ),
                ],
              ),
            ),
            BouncyTap(
              onTap: () => _showPostOptions(context),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  PhosphorIcons.dotsThree(PhosphorIconsStyle.bold),
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Media Section ───────────────────────────────────
  Widget _buildMedia(bool isDark) {
    final width = MediaQuery.of(context).size.width;

    return GestureDetector(
      onDoubleTapDown: (details) => _tapPosition = details.localPosition,
      onDoubleTap: () => _handleLike(isDoubleTap: true),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Media content
          AspectRatio(
            aspectRatio: 1, // Defaulting to 1:1 for simplicity in this demo
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.post.mediaFiles.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final media = widget.post.mediaFiles[index];
                if (media.isVideo) {
                  return VideoPlayerWidget(videoUrl: media.url);
                }
                return InteractiveViewer(
                  transformationController: _transformationController,
                  clipBehavior: Clip.none,
                  minScale: 1.0,
                  maxScale: 4.0,
                  onInteractionEnd: (_) => _transformationController.value = Matrix4.identity(),
                  child: CachedNetworkImage(
                    imageUrl: media.url,
                    fit: BoxFit.cover,
                    width: width,
                  ),
                );
              },
            ),
          ),
          
          // Particles
          if (_showParticles)
            Positioned.fill(
              child: IgnorePointer(
                child: LikeParticles(position: _tapPosition),
              ),
            ),

          // Heart Overlay
          if (_showHeartOverlay)
            Positioned(
              left: _tapPosition.dx - 45,
              top: _tapPosition.dy - 45,
              child: AnimatedBuilder(
                animation: _heartOverlayController,
                builder: (context, child) => Opacity(
                  opacity: _heartOpacity.value,
                  child: Transform.scale(
                    scale: _heartScale.value,
                    child: Icon(
                      PhosphorIcons.heart(PhosphorIconsStyle.fill),
                      color: Colors.white,
                      size: 90,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 20)],
                    ),
                  ),
                ),
              ),
            ),

          // Pagination Dots
          if (widget.post.mediaFiles.length > 1)
            Positioned(
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.post.mediaFiles.length,
                  (index) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index ? const Color(0xFF0095F6) : const Color(0xFFA8A8A8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Action Row (40pt) ────────────────────────────────
  Widget _buildActionRow(bool isDark) {
    final iconColor = isDark ? Colors.white : Colors.black;

    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            // Like
            BouncyTap(
              onTap: () => _handleLike(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ScaleTransition(
                  scale: _likeBounceScale,
                  child: Icon(
                    _isLiked ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(PhosphorIconsStyle.bold),
                    color: _isLiked ? const Color(0xFFFF3040) : iconColor,
                    size: 26,
                  ),
                ),
              ),
            ),
            // Comment
            BouncyTap(
              onTap: () => context.push('/post/${widget.post.id}/comments', extra: widget.post),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(PhosphorIcons.chatCircle(PhosphorIconsStyle.bold), color: iconColor, size: 26),
              ),
            ),
            // Share
            BouncyTap(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.bold), color: iconColor, size: 26),
              ),
            ),
            const Spacer(),
            // Save
            BouncyTap(
              onTap: _handleSave,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ScaleTransition(
                  scale: _saveBounceScale,
                  child: Icon(
                    _isSaved ? PhosphorIcons.bookmark(PhosphorIconsStyle.fill) : PhosphorIcons.bookmark(PhosphorIconsStyle.bold),
                    color: iconColor,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Likes Count ─────────────────────────────────────
  Widget _buildLikes(bool isDark) {
    if (_likeCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Text(
        '$_likeCount likes',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF262626),
        ),
      ),
    );
  }

  // ─── Caption ─────────────────────────────────────────
  Widget _buildCaption(bool isDark) {
    final caption = widget.post.caption ?? '';
    if (caption.isEmpty) return const SizedBox.shrink();

    final showMore = !_captionExpanded && caption.length > 100;
    final displayCaption = showMore ? '${caption.substring(0, 100)}' : caption;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: GestureDetector(
          onTap: () {
            if (caption.length > 100) {
              setState(() => _captionExpanded = !_captionExpanded);
            }
          },
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF262626),
                fontFamily: 'SF-Pro',
              ),
              children: [
                TextSpan(
                  text: '${widget.post.username} ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => context.push('/profile/${widget.post.username}'),
                ),
                TextSpan(text: displayCaption),
                if (showMore)
                  TextSpan(
                    text: '... more',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF8E8E8E),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Comments Preview ────────────────────────────────
  Widget _buildCommentsPreview(bool isDark) {
    if (widget.post.commentsCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: BouncyTap(
        onTap: () => context.push('/post/${widget.post.id}/comments', extra: widget.post),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'View all ${widget.post.commentsCount} comments',
            style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E), decoration: TextDecoration.none),
          ),
        ),
      ),
    );
  }

  // ─── Timestamp ───────────────────────────────────────
  Widget _buildTimestamp(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Text(
        timeago.format(widget.post.createdAt).toUpperCase(),
        style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E8E), letterSpacing: 0.5),
      ),
    );
  }

  void _showPostOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Share')),
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Link')),
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
}

class LikeParticles extends StatefulWidget {
  final Offset position;

  const LikeParticles({super.key, required this.position});

  @override
  State<LikeParticles> createState() => _LikeParticlesState();
}

class _LikeParticlesState extends State<LikeParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ParticleData> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    final random = math.Random();
    for (int i = 0; i < 6; i++) {
      _particles.add(_ParticleData(
        angle: (random.nextDouble() * 2 - 1) * 0.5 - 1.57, // Upwards range
        velocity: 2.0 + random.nextDouble() * 2.0,
        size: 10.0 + random.nextDouble() * 10.0,
      ));
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: _particles.map((p) {
            final t = _controller.value;
            final dx = p.velocity * 100 * t * math.cos(p.angle);
            final dy = p.velocity * 100 * t * math.sin(p.angle);
            final opacity = (1.0 - t).clamp(0.0, 1.0);
            
            return Positioned(
              left: widget.position.dx + dx,
              top: widget.position.dy + dy,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: 0.5 + t * 0.5,
                  child: Icon(
                    PhosphorIcons.heart(PhosphorIconsStyle.fill),
                    color: Colors.white.withAlpha(204), // 0.8 * 255
                    size: p.size,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ParticleData {
  final double angle;
  final double velocity;
  final double size;

  _ParticleData({required this.angle, required this.velocity, required this.size});
}
