// lib/features/post/presentation/widgets/video_player_widget.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/video_player_manager.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final int? duration;
  final bool autoPlay;
  final bool showControls;
  final bool looping;
  final double aspectRatio;
  final BoxFit fit;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.duration,
    this.autoPlay = true,
    this.showControls = true,
    this.looping = true,
    this.aspectRatio = 1.0,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = true;       // Start muted (like Instagram)
  bool _showPlayIcon = false;  // Briefly show play/pause icon on tap
  bool _isVisible = false;
  bool _hasError = false;

  // ─── For the brief play/pause icon ───────────────────
  late AnimationController _iconAnimController;
  late Animation<double> _iconOpacity;

  @override
  void initState() {
    super.initState();

    // Setup icon fade animation
    _iconAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _iconAnimController,
        curve: Curves.easeOut,
      ),
    );

    _initializeVideo();
  }

  @override
  void dispose() {
    _iconAnimController.dispose();
    _pause(); // Ensure video is paused when widget is removed
    super.dispose();
  }

  // ─── Initialize video player ──────────────────────────
  Future<void> _initializeVideo() async {
    try {
      _controller = await VideoPlayerManager().getController(widget.videoUrl);

      if (!mounted) return;

      _controller!.setLooping(widget.looping);
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);

      setState(() {
        _isInitialized = true;
        _isPlaying = false;
      });

      // Auto-play if visible
      if (_isVisible && widget.autoPlay) {
        _play();
      }
    } catch (e, stack) {
      debugPrint('❌ VideoPlayer pool error: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  // ─── Playback controls ────────────────────────────────
  void _play() {
    if (!_isInitialized || _controller == null) return;
    if (!mounted) return;
    _controller!.play();
    setState(() => _isPlaying = true);
  }

  void _pause() {
    if (!_isInitialized || _controller == null) return;
    if (!mounted) return;
    _controller!.pause();
    setState(() => _isPlaying = false);
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
    // Show brief icon
    if (!mounted) return;
    setState(() => _showPlayIcon = true);
    _iconAnimController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showPlayIcon = false);
    });
  }

  void _toggleMute() {
    if (_controller == null) return;
    if (!mounted) return;
    setState(() => _isMuted = !_isMuted);
    _controller!.setVolume(_isMuted ? 0.0 : 1.0);
  }

  // ─── Visibility handler ───────────────────────────────
  void _onVisibilityChanged(VisibilityInfo info) {
    final isVisible = info.visibleFraction > 0.5;

    if (isVisible == _isVisible) return;
    _isVisible = isVisible;

    if (isVisible && widget.autoPlay) {
      _play();
    } else {
      _pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video-${widget.videoUrl}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: _togglePlayPause,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ─── Video or thumbnail ───────────────────
              _buildVideoContent(),

              // ─── Mute button ──────────────────────────
              if (widget.showControls && _isInitialized)
                _buildMuteButton(),

              // ─── Duration badge ───────────────────────
              if (widget.duration != null)
                _buildDurationBadge(),

              // ─── Play/Pause overlay icon ──────────────
              if (_showPlayIcon)
                _buildPlayPauseOverlay(),

              // ─── Progress bar at bottom ───────────────
              if (_isInitialized && widget.showControls)
                _buildProgressBar(),

              // ─── Loading indicator ────────────────────
              if (!_isInitialized && !_hasError)
                _buildLoadingIndicator(),

              // ─── Error state ──────────────────────────
              if (_hasError)
                _buildErrorState(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // VIDEO CONTENT
  // ─────────────────────────────────────────────────────
  Widget _buildVideoContent() {
    if (!_isInitialized || _controller == null) {
      // Show thumbnail while loading
      if (widget.thumbnailUrl != null) {
        return Image.network(
          widget.thumbnailUrl!,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
      return _buildPlaceholder();
    }

    return FittedBox(
      fit: widget.fit,
      child: SizedBox(
        width: _controller!.value.size.width,
        height: _controller!.value.size.height,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // MUTE BUTTON (bottom right)
  // ─────────────────────────────────────────────────────
  Widget _buildMuteButton() {
    return Positioned(
      bottom: 12,
      right: 12,
      child: GestureDetector(
        onTap: _toggleMute,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isMuted ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // DURATION BADGE (top right) - shown when paused
  // ─────────────────────────────────────────────────────
  Widget _buildDurationBadge() {
    if (_isPlaying) return const SizedBox.shrink();

    final minutes = widget.duration! ~/ 60;
    final seconds = widget.duration! % 60;
    final formatted = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Positioned(
      top: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          formatted,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // PLAY/PAUSE OVERLAY (briefly shown on tap)
  // ─────────────────────────────────────────────────────
  Widget _buildPlayPauseOverlay() {
    return Center(
      child: FadeTransition(
        opacity: _iconOpacity,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isPlaying ? Icons.play_arrow : Icons.pause,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // PROGRESS BAR (bottom of video)
  // ─────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: VideoProgressIndicator(
        _controller!,
        allowScrubbing: true,
        colors: const VideoProgressColors(
          playedColor: Colors.white,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.transparent,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // LOADING INDICATOR
  // ─────────────────────────────────────────────────────
  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // ERROR STATE
  // ─────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined, color: Colors.white54, size: 40),
            SizedBox(height: 8),
            Text(
              'Video unavailable',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // PLACEHOLDER (before initialized)
  // ─────────────────────────────────────────────────────
  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          color: Colors.white30,
          size: 48,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// THUMBNAIL WIDGET
// Shows thumbnail for video in grid view (explore + profile)
// ─────────────────────────────────────────────────────
class VideoThumbnail extends StatelessWidget {
  final String? thumbnailUrl;
  final String? videoUrl;
  final int? duration;
  final BoxFit fit;

  const VideoThumbnail({
    super.key,
    this.thumbnailUrl,
    this.videoUrl,
    this.duration,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ─── Thumbnail image ────────────────────────────
        if (thumbnailUrl != null)
          Image.network(
            thumbnailUrl!,
            fit: fit,
            errorBuilder: (_, __, ___) => Container(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
            ),
          )
        else
          Container(
            color: Colors.black,
            child: const Icon(
              Icons.play_circle_outline,
              color: Colors.white30,
              size: 32,
            ),
          ),

        // ─── Video icon (top right) ─────────────────────
        const Positioned(
          top: 6,
          right: 6,
          child: Icon(
            Icons.videocam,
            color: Colors.white,
            size: 18,
            shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
          ),
        ),

        // ─── Duration badge (bottom right) ─────────────
        if (duration != null)
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                _formatDuration(duration!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
