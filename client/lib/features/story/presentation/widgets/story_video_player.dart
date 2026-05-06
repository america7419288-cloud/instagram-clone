import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/cupertino.dart';

class StoryVideoPlayer extends StatefulWidget {
  final String url;
  final bool isPaused;
  final VoidCallback onVideoFinished;
  final Function(Duration) onDurationLoaded;

  const StoryVideoPlayer({
    super.key,
    required this.url,
    required this.isPaused,
    required this.onVideoFinished,
    required this.onDurationLoaded,
  });

  @override
  State<StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<StoryVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        widget.onDurationLoaded(_controller.value.duration);
        if (!widget.isPaused) {
          _controller.play();
        }
        _controller.addListener(_videoListener);
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
    }
  }

  void _videoListener() {
    if (_controller.value.position >= _controller.value.duration) {
      widget.onVideoFinished();
      _controller.removeListener(_videoListener);
    }
  }

  @override
  void didUpdateWidget(StoryVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      if (widget.isPaused && !oldWidget.isPaused) {
        _controller.pause();
      } else if (!widget.isPaused && oldWidget.isPaused) {
        _controller.play();
      }
    }
    
    if (widget.url != oldWidget.url) {
      _controller.dispose();
      _isInitialized = false;
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CupertinoActivityIndicator(color: Colors.white, radius: 15),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}
