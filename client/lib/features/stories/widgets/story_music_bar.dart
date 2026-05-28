import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story_model.dart';

class StoryMusicBar extends StatefulWidget {
  final StoryMusicData music;
  final bool isPlaying;

  const StoryMusicBar({
    super.key,
    required this.music,
    this.isPlaying = true,
  });

  @override
  State<StoryMusicBar> createState() => _StoryMusicBarState();
}

class _StoryMusicBarState extends State<StoryMusicBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Album art with rotation or simple rounded corners
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: widget.music.albumArtUrl,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.white24),
              errorWidget: (_, __, ___) => const Icon(
                Icons.music_note,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Song / Artist name text scrolling or simple
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.music.songName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                widget.music.artistName,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Dynamic Equalizer Icon
          if (widget.isPlaying)
            _EqualizerVisualizer(
              animation: _animationController,
            )
          else
            const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 14,
            ),
        ],
      ),
    );
  }
}

class _EqualizerVisualizer extends StatelessWidget {
  final Animation<double> animation;

  const _EqualizerVisualizer({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (index) {
            // Generate distinct waves for each bar using sin functions
            final double progress = animation.value;
            final double wave = math.sin((progress * 2 * math.pi) + (index * 1.5));
            final double heightFactor = (wave.abs() * 10).clamp(2.0, 14.0);

            return Container(
              width: 2.5,
              height: heightFactor,
              margin: const EdgeInsets.symmetric(horizontal: 0.75),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        );
      },
    );
  }
}
