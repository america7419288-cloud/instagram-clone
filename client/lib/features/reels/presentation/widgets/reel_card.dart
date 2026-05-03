// lib/features/reels/presentation/widgets/reel_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/reel_model.dart';
import '../providers/reel_provider.dart';
import 'reel_action_buttons.dart';

class ReelCard extends ConsumerStatefulWidget {
  final ReelModel reel;
  final bool isActive; // Is this the currently visible reel?
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
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPaused = false;
  bool _isMuted = false;
  bool _showPauseIcon = false;
  bool _hasError = false;

  // ─── Pause icon fade ──────────────────────────────────
  late AnimationController _pauseIconController;
  late Animation<double> _pauseIconOpacity;

  // ─── Caption expand ───────────────────────────────────
  bool _captionExpanded = false;

  // ─── Optimistic state ─────────────────────────────────
  late bool _isLiked;
  late int _likeCount;

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

    _initVideo();
  }

  @override
  void didUpdateWidget(ReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ─── Play/pause based on active state ─────────────
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _play();
      } else {
        _pause();
        _controller?.seekTo(Duration.zero);
      }
    }

    // ─── Sync like state if reel changed ──────────────
    if (widget.reel.isLiked != oldWidget.reel.isLiked ||
        widget.reel.likesCount != oldWidget.reel.likesCount) {
      if (!_isLiked) {
        // Only sync if we haven't optimistically updated
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
    _controller?.dispose();
    super.dispose();
  }

  // ─── Initialize video ─────────────────────────────────
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

      // Auto-play if this is the active reel
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
    // Show brief icon
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

  // ─── Like handler ─────────────────────────────────────
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

  // ─── Double tap like ──────────────────────────────────
  void _handleDoubleTap() {
    HapticFeedback.heavyImpact();
    if (!_isLiked) _handleLike();
  }

  // ─── Show comments ────────────────────────────────────
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

  // ─── Share sheet ──────────────────────────────────────
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
      onDoubleTap: _handleDoubleTap,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ─── Video / thumbnail ────────────────────────
            _buildVideoLayer(),

            // ─── Gradient overlays ────────────────────────
            _buildGradients(),

            // ─── Pause icon overlay ───────────────────────
            if (_showPauseIcon) _buildPauseIcon(),

            // ─── Bottom info (left side) ──────────────────
            _buildBottomInfo(context),

            // ─── Action buttons (right side) ──────────────
            _buildActionButtonsPanel(context),

            // ─── Top bar (mute + more) ────────────────────
            _buildTopBar(),

            // ─── Progress bar ─────────────────────────────
            if (_isInitialized && _controller != null)
              _buildProgressBar(),

            // ─── Loading state ────────────────────────────
            if (!_isInitialized && !_hasError) _buildLoader(),

            // ─── Error state ──────────────────────────────
            if (_hasError) _buildError(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // VIDEO LAYER
  // ─────────────────────────────────────────────────────
  Widget _buildVideoLayer() {
    if (!_isInitialized || _controller == null) {
      // Thumbnail while loading
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

  // ─────────────────────────────────────────────────────
  // GRADIENTS (top + bottom)
  // ─────────────────────────────────────────────────────
  Widget _buildGradients() {
    return Stack(
      children: [
        // Top gradient (for status bar readability)
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
        // Bottom gradient (for text readability)
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

  // ─────────────────────────────────────────────────────
  // PAUSE ICON OVERLAY
  // ─────────────────────────────────────────────────────
  Widget _buildPauseIcon() {
    return Center(
      child: FadeTransition(
        opacity: _pauseIconOpacity,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isPaused ? Icons.play_arrow : Icons.pause,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // BOTTOM INFO (left side)
  // ─────────────────────────────────────────────────────
  Widget _buildBottomInfo(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 16,
      right: 80, // leave space for action buttons
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Username ───────────────────────────────────
          GestureDetector(
            onTap: () =>
                context.push('/profile/${widget.reel.username}'),
            child: Row(
              children: [
                Text(
                  '@${widget.reel.username}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(blurRadius: 4, color: Colors.black54),
                    ],
                  ),
                ),
                if (widget.reel.isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ],
            ),
          ),

          // ─── Caption ────────────────────────────────────
          if (widget.reel.caption != null &&
              widget.reel.caption!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () =>
                  setState(() => _captionExpanded = !_captionExpanded),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  widget.reel.caption!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                    shadows: [
                      Shadow(blurRadius: 4, color: Colors.black45),
                    ],
                  ),
                  maxLines: _captionExpanded ? null : 2,
                  overflow: _captionExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
              ),
            ),
          ],

          // ─── Audio name ticker ──────────────────────────
          const SizedBox(height: 12),
          _AudioTicker(
            audioName: widget.reel.audioName ??
                'Original audio · ${widget.reel.username}',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // ACTION BUTTONS PANEL (right side)
  // ─────────────────────────────────────────────────────
  Widget _buildActionButtonsPanel(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 80,
      child: ReelActionButtons(
        reel: widget.reel.copyWith(
          isLiked: _isLiked,
          likesCount: _likeCount,
        ),
        onLike: _handleLike,
        onComment: () => _showComments(context),
        onShare: () => _showShareSheet(context),
        onAudio: () {},
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // TOP BAR (mute + back)
  // ─────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ─── Reels title ─────────────────────────────
              const Text(
                'Reels',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black45),
                  ],
                ),
              ),
              // ─── Mute button ─────────────────────────────
              GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // PROGRESS BAR (thin, at very bottom)
  // ─────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: VideoProgressIndicator(
        _controller!,
        allowScrubbing: false,
        colors: const VideoProgressColors(
          playedColor: Colors.white,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildError() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.white54, size: 40),
          SizedBox(height: 8),
          Text(
            'Reel unavailable',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// AUDIO TICKER (scrolling text like Instagram)
// ─────────────────────────────────────────────────────
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
        const Icon(
          Icons.music_note,
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

// ─────────────────────────────────────────────────────
// COMMENTS SHEET (bottom sheet)
// ─────────────────────────────────────────────────────
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
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
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
          // Comments list - TODO: implement with comment provider
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

// ─────────────────────────────────────────────────────
// SHARE SHEET
// ─────────────────────────────────────────────────────
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
            leading: const Icon(Icons.link),
            title: const Text('Copy link'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.near_me_outlined),
            title: const Text('Send to...'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share to...'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}