// lib/features/reels/presentation/widgets/reel_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/reel_model.dart';
import '../providers/reel_provider.dart';
import '../../../../shared/widgets/spring_widget.dart';
import 'reel_action_buttons.dart';

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

  late AnimationController _pauseIconController;
  late Animation<double> _pauseIconOpacity;
  late AnimationController _heartAnimationController;
  final List<Offset> _hearts = [];
  bool _captionExpanded = false;
  late bool _isLiked;
  late int _likeCount;
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
      CurvedAnimation(
        parent: _pauseIconController,
        curve: Curves.easeOut,
      ),
    );

    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _albumArtController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

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

      setState(() => _isInitialized = true);

      if (widget.isActive) _play();
    } catch (e) {
      debugPrint('❌ Reel video init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _play() {
    if (!_isInitialized || _controller == null) return;
    _controller!.play();
    if (mounted) setState(() => _isPaused = false);
  }

  void _pause() {
    if (!_isInitialized || _controller == null) return;
    _controller!.pause();
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
    HapticFeedback.heavyImpact();
    
    setState(() {
      _hearts.add(details.localPosition);
    });

    _heartAnimationController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _hearts.clear());
      }
    });

    if (!_isLiked) _handleLike();
  }

  void _showComments(BuildContext context) {
    _pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(reelId: widget.reel.id),
    ).then((_) {
      if (widget.isActive) _play();
    });
  }

  void _showShareSheet(BuildContext context) {
    _pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(),
    ).then((_) {
      if (widget.isActive) _play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTapDown: _handleDoubleTap,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoLayer(),
            _buildGradients(),
            ..._hearts.map((pos) => _buildDoubleTapHeart(pos)),
            if (_showPauseIcon) _buildPauseIcon(),
            _buildTopBar(),
            _buildBottomInfo(context),
            _buildActionButtonsPanel(context),
            if (!_isInitialized && !_hasError) _buildLoader(),
            if (_hasError) _buildError(),
          ],
        ),
      ),
    );
  }

  Widget _buildDoubleTapHeart(Offset position) {
    return Positioned(
      left: position.dx - 50,
      top: position.dy - 50,
      child: AnimatedBuilder(
        animation: _heartAnimationController,
        builder: (context, child) {
          final value = _heartAnimationController.value;
          final scale = value < 0.2 ? value * 5 : (value < 0.5 ? 1.0 : (1.0 - (value - 0.5) * 2));
          final opacity = value < 0.8 ? 1.0 : (1.0 - (value - 0.8) * 5).clamp(0.0, 1.0);
          
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 100,
                shadows: [Shadow(blurRadius: 20, color: Colors.black45)],
              ),
            ),
          );
        },
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

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller!.value.size.width,
        height: _controller!.value.size.height,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildGradients() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 150,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black38, Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 300,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPauseIcon() {
    return Center(
      child: FadeTransition(
        opacity: _pauseIconOpacity,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isPaused ? PhosphorIcons.play() : PhosphorIcons.pause(),
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
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
                ),
              ),
              BouncyTap(
                onTap: () {},
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInfo(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 12,
      right: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          BouncyTap(
            onTap: () => context.push('/profile/${widget.reel.username}'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.reel.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'SF Pro Text',
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
                if (widget.reel.isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified, color: Colors.blue, size: 14),
                ],
              ],
            ),
          ),
          if (widget.reel.caption != null && widget.reel.caption!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _captionExpanded = !_captionExpanded),
              child: RichText(
                maxLines: _captionExpanded ? null : 1,
                overflow: _captionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: widget.reel.caption!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'SF Pro Text',
                      ),
                    ),
                    if (!_captionExpanded && widget.reel.caption!.length > 40)
                      const TextSpan(
                        text: ' ...more',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _AudioTicker(
            audioName: widget.reel.audioName ?? 'Original Audio - ${widget.reel.username}',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsPanel(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 80,
      child: Column(
        children: [
          ReelActionButtons(
            reel: widget.reel.copyWith(
              isLiked: _isLiked,
              likesCount: _likeCount,
            ),
            onLike: _handleLike,
            onComment: () => _showComments(context),
            onShare: () => _showShareSheet(context),
            onAudio: () {},
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _albumArtController,
            builder: (_, child) {
              return Transform.rotate(
                angle: _albumArtController.value * 2 * 3.14159,
                child: child,
              );
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: widget.reel.thumbnailUrl != null
                    ? Image.network(
                        widget.reel.thumbnailUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(color: Colors.grey),
              ),
            ),
          ),
        ],
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
          Icon(PhosphorIcons.warningCircle(), color: Colors.white54, size: 40),
          const SizedBox(height: 8),
          const Text(
            'Reel unavailable',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _AudioTicker extends StatefulWidget {
  final String audioName;
  const _AudioTicker({required this.audioName});

  @override
  State<_AudioTicker> createState() => _AudioTickerState();
}

class _AudioTickerState extends State<_AudioTicker>
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
      CurvedAnimation(
        parent: _scrollController,
        curve: Curves.linear,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          PhosphorIcons.musicNote(),
          color: Colors.white,
          size: 14,
          shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
        ),
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
                '${widget.audioName}   •   ${widget.audioName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black45),
                  ],
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentsSheet extends StatelessWidget {
  final String reelId;
  const _CommentsSheet({required this.reelId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Comments',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          const Expanded(
            child: Center(
              child: Text(
                'Comments coming soon',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Icon(PhosphorIcons.link()),
            title: const Text('Copy link'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(PhosphorIcons.paperPlaneTilt()),
            title: const Text('Send to...'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(PhosphorIcons.shareNetwork()),
            title: const Text('Share to...'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
