// lib/features/reels/presentation/widgets/reel_card.dart

import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:shimmer/shimmer.dart';

import 'package:instagram_client/core/theme/app_theme.dart';
import '../../data/models/reel_model.dart';
import '../providers/reel_provider.dart';
import 'package:instagram_client/shared/widgets/spring_widget.dart';
import 'package:instagram_client/shared/widgets/verified_badge.dart';
import 'package:instagram_client/core/widgets/instagram_heart_animation.dart';
import 'package:instagram_client/core/router/app_router.dart';
import 'package:instagram_client/features/share/models/share_content.dart';
import 'package:instagram_client/features/share/presentation/share_sheet.dart';
import 'package:instagram_client/features/menu/presentation/three_dot_menu.dart';
import 'package:instagram_client/features/menu/models/menu_context.dart';
import 'package:instagram_client/features/menu/models/menu_action.dart';
import 'package:instagram_client/features/follow/data/repositories/presentation/providers/follow_provider.dart';
import 'package:instagram_client/features/post/data/models/comment_model.dart';
import 'package:instagram_client/features/post/presentation/providers/comment_provider.dart';

// ── Particle Confetti Physics ──────────────────────────────
class _HeartParticle {
  final Offset origin;
  final double angle;
  final double speed;
  double scale = 1.0;
  double opacity = 1.0;
  Offset currentPos;

  _HeartParticle({required this.origin, required this.angle, required this.speed})
      : currentPos = origin;

  void update() {
    currentPos = Offset(
      currentPos.dx + speed * cos(angle),
      currentPos.dy + speed * sin(angle),
    );
    scale = (scale - 0.035).clamp(0.0, 1.0);
    opacity = (opacity - 0.045).clamp(0.0, 1.0);
  }
}

class ParticlePainter extends CustomPainter {
  final List<_HeartParticle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (final p in particles) {
      if (p.opacity <= 0 || p.scale <= 0) continue;
      
      paint.color = const Color(0xFFED4956).withOpacity(p.opacity);
      
      final double r = 8.0 * p.scale;
      final path = Path();
      final dx = p.currentPos.dx;
      final dy = p.currentPos.dy;
      
      path.moveTo(dx, dy + r / 4);
      path.cubicTo(dx - r / 2, dy - r / 4, dx - r, dy + r / 3, dx, dy + r);
      path.cubicTo(dx + r, dy + r / 3, dx + r / 2, dy - r / 4, dx, dy + r / 4);
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── Count Text Animation Ticker ───────────────────────────
class _AnimatedCountText extends StatelessWidget {
  final int count;
  final TextStyle style;

  const _AnimatedCountText({required this.count, required this.style});

  @override
  Widget build(BuildContext context) {
    final formatted = _formatCount(count);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.4),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Text(
        formatted,
        key: ValueKey<String>(formatted),
        style: style,
      ),
    );
  }

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

// ── Main Reels Card Widget ────────────────────────────────
class ReelCard extends ConsumerStatefulWidget {
  final ReelModel reel;
  final bool isActive;
  final VoidCallback? onVideoEnd;

  const ReelCard({
    super.key,
    required this.reel,
    required this.isActive,
    this.onVideoEnd,
  });

  @override
  ConsumerState<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends ConsumerState<ReelCard>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPaused = false;
  bool _isMuted = false;
  bool _showPauseIcon = false;
  bool _hasError = false;

  // Gesture scale & hold states
  double _scale = 1.0;
  double _baseScale = 1.0;
  bool _isHolding = false;

  // Bottom timeline seeking states
  bool _isDraggingProgress = false;
  double _dragProgress = 0.0;
  double _dragXOffset = 0.0;

  // Count/Likes states
  late bool _isLiked;
  late int _likeCount;
  bool _captionExpanded = false;

  // Animation controllers
  late AnimationController _pauseIconController;
  late Animation<double> _pauseIconOpacity;

  late AnimationController _heartAnimationController;
  final List<Offset> _hearts = [];
  bool _heartAnimating = false;

  // Confetti particles
  late AnimationController _particleController;
  final List<_HeartParticle> _particles = [];

  // Sidebar animations
  late AnimationController _likeAnimationController;
  late Animation<double> _likeScale;
  late AnimationController _shareAnimationController;
  late Animation<double> _shareRotation;
  late AnimationController _albumArtController;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.reel.isLiked;
    _likeCount = widget.reel.likesCount;

    _pauseIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pauseIconOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _pauseIconController, curve: Curves.easeOut),
    );

    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        if (mounted) {
          setState(() {
            for (final p in _particles) {
              p.update();
            }
          });
        }
      });

    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.easeOutBack,
    ));

    _shareAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shareRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 20.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 20.0, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _shareAnimationController,
      curve: Curves.easeInOut,
    ));

    _albumArtController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _initVideo();
  }

  @override
  void didUpdateWidget(ReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _play();
      } else {
        _pause();
        _controller?.seekTo(Duration.zero);
      }
    }

    if (widget.reel.isLiked != oldWidget.reel.isLiked ||
        widget.reel.likesCount != oldWidget.reel.likesCount) {
      if (!_isLiked) {
        setState(() {
          _isLiked = widget.reel.isLiked;
          _likeCount = widget.reel.likesCount;
        });
      }
    }
  }

  @override
  void dispose() {
    _pauseIconController.dispose();
    _heartAnimationController.dispose();
    _particleController.dispose();
    _likeAnimationController.dispose();
    _shareAnimationController.dispose();
    _albumArtController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.reel.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _controller!.initialize();

      if (!mounted) return;

      _controller!.setLooping(true);
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      _controller!.addListener(_videoListener);

      setState(() => _isInitialized = true);

      if (widget.isActive) _play();
    } catch (e) {
      debugPrint('❌ Reel video init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _videoListener() {
    if (mounted) {
      // Re-trigger layout updates for the progress slider position
      setState(() {});
    }
  }

  void _play() {
    if (!_isInitialized || _controller == null) return;
    _controller!.play();
    _albumArtController.repeat();
    if (mounted) setState(() => _isPaused = false);
  }

  void _pause() {
    if (!_isInitialized || _controller == null) return;
    _controller!.pause();
    _albumArtController.stop();
    if (mounted) setState(() => _isPaused = true);
  }

  void _togglePlayPause() {
    if (_isPaused) {
      _play();
    } else {
      _pause();
    }
    setState(() => _showPauseIcon = true);
    _pauseIconController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showPauseIcon = false);
    });
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() => _isMuted = !_isMuted);
    _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    HapticFeedback.selectionClick();
  }

  Future<void> _handleLike() async {
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      if (wasLiked) {
        await ref.read(reelFeedProvider.notifier).unlikeReel(widget.reel.id);
      } else {
        await ref.read(reelFeedProvider.notifier).likeReel(widget.reel.id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount += wasLiked ? 1 : -1;
        });
      }
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (_heartAnimating) return;
    HapticFeedback.heavyImpact();
    
    setState(() {
      _heartAnimating = true;
      _hearts.add(details.localPosition);

      // Create confetti burst particles
      _particles.clear();
      final random = Random();
      for (int i = 0; i < 12; i++) {
        final angle = random.nextDouble() * 2 * pi;
        final speed = 3.0 + random.nextDouble() * 5.0;
        _particles.add(_HeartParticle(
          origin: details.localPosition,
          angle: angle,
          speed: speed,
        ));
      }
    });

    _heartAnimationController.forward(from: 0.0);
    _particleController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _hearts.clear();
          _particles.clear();
          _heartAnimating = false;
        });
      }
    });

    if (!_isLiked) _handleLike();
  }

  void _showComments(BuildContext context) {
    _pause();
    _CommentsSheet.show(context, widget.reel.id).then((_) {
      if (widget.isActive) _play();
    });
  }

  void _showShareSheet(BuildContext context) {
    _pause();
    ShareSheet.show(
      context,
      content: ShareContent(
        id: widget.reel.id,
        type: ShareContentType.reel,
        thumbnailUrl: widget.reel.thumbnailUrl,
        authorUsername: widget.reel.username,
        authorAvatarUrl: widget.reel.userAvatar,
        caption: widget.reel.caption,
      ),
    ).then((_) {
      if (widget.isActive) _play();
    });
  }

  void _showReelOptions(BuildContext context) {
    _pause();
    
    final relationship = widget.reel.isOwnReel
        ? MenuRelationship.owner
        : (widget.reel.isFollowing
            ? MenuRelationship.following
            : MenuRelationship.notFollowing);

    final menuContext = MenuContext(
      contentId: widget.reel.id,
      contentType: MenuContentType.reel,
      relationship: relationship,
      authorId: widget.reel.userId,
      authorUsername: widget.reel.username,
      authorAvatarUrl: widget.reel.userAvatar,
      isVerified: widget.reel.isVerified,
      canDelete: widget.reel.isOwnReel,
      canEdit: widget.reel.isOwnReel,
      canDownload: true,
      canRemix: true,
    );

    InstagramMenu.show(
      context,
      menuContext: menuContext,
      onAction: _handleMenuAction,
    ).then((_) {
      if (widget.isActive) _play();
    });
  }

  Future<void> _handleMenuAction(MenuAction action) async {
    switch (action.type) {
      case MenuActionType.copyLink:
        Clipboard.setData(ClipboardData(text: 'https://instagram.com/reels/${widget.reel.id}'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard')),
        );
        break;
      case MenuActionType.delete:
        try {
          await ref.read(reelFeedProvider.notifier).deleteReel(widget.reel.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reel deleted')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete reel: $e')),
            );
          }
        }
        break;
      case MenuActionType.save:
      case MenuActionType.saveCollection:
      case MenuActionType.unsave:
        try {
          await ref.read(reelFeedProvider.notifier).toggleSave(widget.reel.id);
          if (mounted) {
            final isSaved = ref.read(reelFeedProvider).reels
                .firstWhere((r) => r.id == widget.reel.id).isSaved;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isSaved ? 'Reel saved' : 'Reel removed from saved'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update save: $e')),
            );
          }
        }
        break;
      case MenuActionType.remix:
        context.push(AppRoutes.createReel);
        break;
      case MenuActionType.unfollow:
        try {
          await ref.read(followProvider(widget.reel.userId).notifier).toggleFollow();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unfollowed @${widget.reel.username}')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to unfollow: $e')),
            );
          }
        }
        break;
      case MenuActionType.report:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thanks for your feedback.')),
        );
        break;
      case MenuActionType.hide:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel hidden')),
        );
        break;
      case MenuActionType.notInterested:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('We\'ll show fewer reels like this')),
        );
        break;
      default:
        debugPrint('Unhandled menu action: ${action.type}');
    }
  }

  // ── Drag seeking timeline functions ────────────────────────
  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDraggingProgress = true;
      _dragXOffset = details.localPosition.dx;
    });
    _updateDragProgress(details.localPosition.dx);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragXOffset = details.localPosition.dx;
    });
    _updateDragProgress(details.localPosition.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    _seekToProgress();
    setState(() {
      _isDraggingProgress = false;
    });
  }

  void _onTapDown(TapDownDetails details) {
    _updateDragProgress(details.localPosition.dx);
    _seekToProgress();
  }

  void _updateDragProgress(double localX) {
    final screenWidth = MediaQuery.of(context).size.width;
    final progress = (localX / screenWidth).clamp(0.0, 1.0);
    setState(() {
      _dragProgress = progress;
    });
  }

  void _seekToProgress() {
    if (_controller == null || !_isInitialized) return;
    final duration = _controller!.value.duration;
    final seekPos = duration * _dragProgress;
    _controller!.seekTo(seekPos);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final showUI = !_isHolding && _scale == 1.0;
    final showProgressBar = _scale == 1.0;

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTapDown: _handleDoubleTap,
      onLongPressStart: (_) {
        setState(() => _isHolding = true);
        _pause();
      },
      onLongPressEnd: (_) {
        setState(() => _isHolding = false);
        _play();
      },
      onScaleStart: (details) {
        if (_isHolding) return;
        _baseScale = _scale;
      },
      onScaleUpdate: (details) {
        if (_isHolding) return;
        setState(() {
          _scale = (_baseScale * details.scale).clamp(1.0, 3.0);
        });
      },
      onScaleEnd: (_) {
        setState(() => _scale = 1.0);
      },
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Video Layer
            _buildVideoLayer(),

            // 2. Gradients overlay
            _buildGradients(showUI),

            // 3. Custom Canvas heart confetti particles
            CustomPaint(
              size: Size.infinite,
              painter: ParticlePainter(_particles),
            ),

            // 4. Double tap floating pop heart overlays
            ..._hearts.map((pos) => _buildDoubleTapHeart(pos)),

            // 5. Center Play/Pause Indicator
            if (_showPauseIcon) _buildPauseIcon(),

            // 6. Long-press quiet dark overlay
            _buildQuietOverlay(),

            // 7. Top App Bar
            _buildTopBar(showUI),

            // 8. Bottom Information Profile & Caption Overlay
            _buildBottomInfo(context, showUI),

            // 9. Right Sidebar Action Capsule Buttons
            _buildActionButtonsPanel(context, showUI),

            // 10. Drag Tooltip floating seek badge
            if (showProgressBar) _buildDragTooltip(),

            // 11. Custom bottom timeline Progress bar
            if (showProgressBar) _buildProgressBar(),

            if (!_isInitialized && !_hasError) _buildLoader(),
            if (_hasError) _buildError(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuietOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _isHolding ? 0.3 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Container(color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildVideoLayer() {
    if (!_isInitialized || _controller == null) {
      if (widget.reel.thumbnailUrl != null) {
        return Image.network(
          widget.reel.thumbnailUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.black),
        );
      }
      return Container(color: Colors.black);
    }

    return Transform.scale(
      scale: _scale,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }

  Widget _buildGradients(bool showUI) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: showUI ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 120,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 280,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPauseIcon() {
    return Center(
      child: FadeTransition(
        opacity: _pauseIconOpacity,
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool showUI) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !showUI,
        child: AnimatedOpacity(
          opacity: showUI ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Reels',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontFamily: 'SF Pro Display',
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      BouncyTap(
                        onTap: () => context.push(AppRoutes.createReel),
                        child: const Icon(LucideIcons.camera, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      BouncyTap(
                        onTap: () {},
                        child: const Icon(LucideIcons.search, color: Colors.white, size: 26),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInfo(BuildContext context, bool showUI) {
    return Positioned(
      bottom: 40,
      left: 12,
      right: 80,
      child: IgnorePointer(
        ignoring: !showUI,
        child: AnimatedOpacity(
          opacity: showUI ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // User info row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => context.push('/profile/${widget.reel.username}'),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white70, width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundImage: widget.reel.userAvatar != null
                            ? CachedNetworkImageProvider(widget.reel.userAvatar!)
                            : null,
                        backgroundColor: Colors.white12,
                        child: widget.reel.userAvatar == null
                            ? const Icon(Icons.person, color: Colors.white, size: 18)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => context.push('/profile/${widget.reel.username}'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.reel.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: 'SF Pro Text',
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                          ),
                        ),
                        if (widget.reel.isVerified) ...[
                          const SizedBox(width: 4),
                          VerifiedBadge(size: 14),
                        ],
                      ],
                    ),
                  ),
                  // Follow button
                  _buildFollowButton(),
                ],
              ),
              const SizedBox(height: 10),
              // Caption expandable
              _buildCaption(),
              const SizedBox(height: 12),
              // Scrolling audio marquee ticker
              _AudioMarquee(
                audioText: widget.reel.audioName ?? 'Original audio - ${widget.reel.username}',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaption() {
    if (widget.reel.caption == null || widget.reel.caption!.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topLeft,
      child: GestureDetector(
        onTap: () => setState(() => _captionExpanded = !_captionExpanded),
        child: RichText(
          maxLines: _captionExpanded ? null : 2,
          overflow: _captionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              ..._buildCaptionSpans(widget.reel.caption!),
              if (!_captionExpanded && widget.reel.caption!.length > 60)
                const TextSpan(
                  text: ' ...more',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (_captionExpanded)
                const TextSpan(
                  text: ' less',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<TextSpan> _buildCaptionSpans(String caption) {
    final words = caption.split(' ');
    return words.map((word) {
      final isHashtag = word.startsWith('#');
      final isMention = word.startsWith('@');
      return TextSpan(
        text: '$word ',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: (isHashtag || isMention) ? FontWeight.w700 : FontWeight.w400,
        ),
      );
    }).toList();
  }

  Widget _buildActionButtonsPanel(BuildContext context, bool showUI) {
    return Positioned(
      right: 12,
      bottom: 80,
      child: IgnorePointer(
        ignoring: !showUI,
        child: AnimatedOpacity(
          opacity: showUI ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Like Button with elastic bounce
              _buildLikeButton(),
              const SizedBox(height: 24),
              // Comments Button
              _buildActionButton(
                icon: LucideIcons.message_circle,
                label: _formatCount(widget.reel.commentsCount),
                onTap: () => _showComments(context),
              ),
              const SizedBox(height: 24),
              // Share Button with rotate bounce
              _buildShareButton(),
              const SizedBox(height: 24),
              // More options
              _buildActionButton(
                icon: LucideIcons.ellipsis,
                label: '',
                onTap: () => _showReelOptions(context),
              ),
              const SizedBox(height: 24),
              // spinning disc player
              _buildRotatingDisc(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLikeButton() {
    return GestureDetector(
      onTap: () {
        _likeAnimationController.forward(from: 0);
        _handleLike();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _likeAnimationController,
            builder: (_, child) {
              return Transform.scale(
                scale: _likeScale.value,
                child: child,
              );
            },
            child: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? const Color(0xFFED4956) : Colors.white,
              size: 30,
              shadows: const [
                Shadow(blurRadius: 8, color: Colors.black38),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _AnimatedCountText(
            count: _likeCount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _shareAnimationController.forward(from: 0);
        _showShareSheet(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _shareAnimationController,
            builder: (_, child) {
              return Transform.rotate(
                angle: _shareRotation.value * pi / 180,
                child: child,
              );
            },
            child: const Icon(
              LucideIcons.send,
              color: Colors.white,
              size: 30,
              shadows: [Shadow(blurRadius: 8, color: Colors.black38)],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 30,
            shadows: const [Shadow(blurRadius: 8, color: Colors.black38)],
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRotatingDisc() {
    return AnimatedBuilder(
      animation: _albumArtController,
      builder: (_, child) {
        return Transform.rotate(
          angle: _albumArtController.value * 2 * pi,
          child: child,
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          gradient: const LinearGradient(
            colors: [Color(0xFF8134AF), Color(0xFFDD2A7B)],
          ),
          image: widget.reel.userAvatar != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(widget.reel.userAvatar!),
                  fit: BoxFit.cover,
                )
              : null,
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 8),
          ],
        ),
        child: widget.reel.userAvatar == null
            ? const Center(
                child: Icon(Icons.music_note, color: Colors.white, size: 16),
              )
            : Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(color: Colors.white30, width: 1.5),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_controller == null || !_isInitialized) return const SizedBox.shrink();

    final duration = _controller!.value.duration;
    final position = _isDraggingProgress
        ? duration * _dragProgress
        : _controller!.value.position;

    double progress = 0.0;
    if (duration.inMilliseconds > 0) {
      progress = position.inMilliseconds / duration.inMilliseconds;
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onTapDown: _onTapDown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: _isDraggingProgress ? 12 : 8),
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track background
              Container(
                height: _isDraggingProgress ? 4 : 2,
                width: double.infinity,
                color: Colors.white.withOpacity(0.3),
              ),
              // Track fill
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: _isDraggingProgress ? 4 : 2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragTooltip() {
    if (!_isDraggingProgress) return const SizedBox.shrink();

    final duration = _controller?.value.duration ?? Duration.zero;
    final currentPos = duration * _dragProgress;
    final tooltipText = _formatDuration(currentPos);

    final screenWidth = MediaQuery.of(context).size.width;
    final leftPos = _dragXOffset.clamp(40.0, screenWidth - 40.0) - 30.0;

    return Positioned(
      bottom: 30,
      left: leftPos,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white10, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          tooltipText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'SF Pro Text',
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CupertinoActivityIndicator(
          color: Colors.white,
          radius: 12,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.circle_alert, color: Colors.white54, size: 40),
          const SizedBox(height: 8),
          const Text(
            'Reel unavailable',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

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

// ── Audio Scrolling Marquee ───────────────────────────────
class _AudioMarquee extends StatefulWidget {
  final String audioText;
  final VoidCallback onTap;

  const _AudioMarquee({required this.audioText, required this.onTap});

  @override
  State<_AudioMarquee> createState() => _AudioMarqueeState();
}

class _AudioMarqueeState extends State<_AudioMarquee>
    with SingleTickerProviderStateMixin {
  late AnimationController _scrollController;
  late Animation<double> _scrollAnim;

  @override
  void initState() {
    super.initState();
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _scrollAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scrollController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.music, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          SizedBox(
            width: 160,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _scrollAnim,
                builder: (_, child) {
                  return FractionalTranslation(
                    translation: Offset(-_scrollAnim.value, 0),
                    child: child,
                  );
                },
                child: Text(
                  '${widget.audioText}    •    ${widget.audioText}    ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Connected Comments Bottom Sheet ───────────────────────────
class _CommentsSheet extends ConsumerStatefulWidget {
  final String reelId;
  const _CommentsSheet({required this.reelId});

  static Future<void> show(BuildContext context, String reelId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => _CommentsSheet(reelId: reelId),
    );
  }

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickEmojis = ['😂', '❤️', '🔥', '🙏', '💯', '🤣'];

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _postComment(CommentState state) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    HapticFeedback.mediumImpact();

    final notifier = ref.read(commentProvider(widget.reelId).notifier);
    if (state.replyingTo != null) {
      await notifier.replyToComment(state.replyingTo!.id, text);
    } else {
      await notifier.addComment(text);
    }
  }

  Future<void> _postQuickEmoji(String emoji) async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(commentProvider(widget.reelId).notifier);
    final state = ref.read(commentProvider(widget.reelId));
    if (state.replyingTo != null) {
      await notifier.replyToComment(state.replyingTo!.id, emoji);
    } else {
      await notifier.addComment(emoji);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentState = ref.watch(commentProvider(widget.reelId));
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75 + keyboardHeight,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Sheet Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                Positioned(
                  right: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.x,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0.5, thickness: 0.5),
          
          // Comments list content
          Expanded(
            child: commentState.isLoading && commentState.comments.isEmpty
                ? _buildSkeletonComments()
                : _buildCommentsList(commentState),
          ),

          // Quick Emojisreaction bar
          if (_commentController.text.isEmpty && commentState.replyingTo == null)
            _buildQuickEmojisRow(),

          // Replying to Indicator Banner
          if (commentState.replyingTo != null)
            _buildReplyBanner(commentState.replyingTo!),

          // Active Input Field Bar
          _buildInputBar(commentState, keyboardHeight, isDark),
        ],
      ),
    );
  }

  Widget _buildCommentsList(CommentState state) {
    if (state.comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.message_circle, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            const Text(
              'No comments yet',
              style: TextStyle(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to share your thoughts!',
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemCount: state.comments.length,
      itemBuilder: (_, i) {
        final comment = state.comments[i];
        return _CommentItem(
          reelId: widget.reelId,
          comment: comment,
          onReply: (replyTarget) {
            ref.read(commentProvider(widget.reelId).notifier).setReplyingTo(replyTarget);
            _focusNode.requestFocus();
          },
        );
      },
    );
  }

  Widget _buildQuickEmojisRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _quickEmojis
            .map((emoji) => GestureDetector(
                  onTap: () => _postQuickEmoji(emoji),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildReplyBanner(CommentModel parent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withOpacity(0.04),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Replying to @${parent.user?.username ?? "user"}',
            style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          GestureDetector(
            onTap: () {
              ref.read(commentProvider(widget.reelId).notifier).setReplyingTo(null);
            },
            child: const Icon(LucideIcons.x, color: Colors.white54, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(CommentState state, double keyboardHeight, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, keyboardHeight > 0 ? 8 : 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.background,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.5)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white12,
            child: Icon(Icons.person, color: Colors.white30, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12, width: 0.5),
              ),
              child: TextField(
                controller: _commentController,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: state.replyingTo != null
                      ? 'Reply to @${state.replyingTo!.user?.username ?? "user"}...'
                      : 'Add a comment...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  suffixIcon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white38, size: 20),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: state.isSubmitting ? null : () => _postComment(state),
            child: state.isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Color(0xFF0095F6),
                    ),
                  )
                : Text(
                    'Post',
                    style: TextStyle(
                      color: _commentController.text.trim().isNotEmpty
                          ? const Color(0xFF0095F6)
                          : const Color(0xFF0095F6).withOpacity(0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonComments() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Shimmer.fromColors(
          baseColor: Colors.white.withOpacity(0.08),
          highlightColor: Colors.white.withOpacity(0.18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Individual Comment Item Widget ─────────────────────────
class _CommentItem extends ConsumerWidget {
  final String reelId;
  final CommentModel comment;
  final Function(CommentModel) onReply;

  const _CommentItem({
    required this.reelId,
    required this.comment,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentState = ref.watch(commentProvider(reelId));
    final replies = commentState.replies[comment.id] ?? [];
    final isLoadingReplies = commentState.loadingReplies[comment.id] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User avatar
              CircleAvatar(
                radius: 16,
                backgroundImage: comment.user?.profilePicUrl != null
                    ? CachedNetworkImageProvider(comment.user!.profilePicUrl!)
                    : null,
                backgroundColor: Colors.white12,
                child: comment.user?.profilePicUrl == null
                    ? const Icon(Icons.person, color: Colors.white30, size: 16)
                    : null,
              ),
              const SizedBox(width: 12),
              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${comment.user?.username ?? "username"} ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: comment.content,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          comment.createdAt != null
                              ? _formatTimestamp(comment.createdAt!)
                              : '1h',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => onReply(comment),
                          child: const Text(
                            'Reply',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Like comment action
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(commentProvider(reelId).notifier).toggleCommentLike(comment.id);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      comment.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: comment.isLiked ? const Color(0xFFED4956) : Colors.white38,
                    ),
                    if (comment.likeCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${comment.likeCount}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          // Replies threads
          if (comment.replyCount > 0) ...[
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 4),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(commentProvider(reelId).notifier).loadReplies(comment.id);
                },
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 0.5,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.repliesExpanded
                          ? 'Hide replies'
                          : 'View ${comment.replyCount} replies',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (comment.repliesExpanded) ...[
              if (isLoadingReplies)
                const Padding(
                  padding: EdgeInsets.only(left: 44, top: 8),
                  child: CupertinoActivityIndicator(radius: 8, color: Colors.white38),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Column(
                    children: replies
                        .map((reply) => _CommentItem(
                              reelId: reelId,
                              comment: reply,
                              onReply: onReply,
                            ))
                        .toList(),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return '1s';
  }
}
