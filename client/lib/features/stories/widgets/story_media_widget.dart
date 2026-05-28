import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/story_model.dart';

class StoryMediaWidget extends StatelessWidget {
  final StoryModel story;
  final VideoPlayerController? videoController;
  final bool isVideoReady;

  const StoryMediaWidget({
    super.key,
    required this.story,
    this.videoController,
    this.isVideoReady = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (story.mediaType) {
      case StoryMediaType.image:
        return _ImageStory(url: story.mediaUrl);
      case StoryMediaType.video:
        return _VideoStory(
          controller: videoController,
          isReady: isVideoReady,
        );
      case StoryMediaType.text:
        return _TextStory(story: story);
      case StoryMediaType.boomerang:
        return _ImageStory(url: story.mediaUrl);
    }
  }
}

class _ImageStory extends StatelessWidget {
  final String url;
  const _ImageStory({required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Container(color: Colors.black),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey.shade900,
        child: const Icon(Icons.broken_image, color: Colors.white54, size: 48),
      ),
    );
  }
}

class _VideoStory extends StatelessWidget {
  final VideoPlayerController? controller;
  final bool isReady;

  const _VideoStory({this.controller, required this.isReady});

  @override
  Widget build(BuildContext context) {
    if (!isReady || controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller!.value.size.width,
          height: controller!.value.size.height,
          child: VideoPlayer(controller!),
        ),
      ),
    );
  }
}

class _TextStory extends StatelessWidget {
  final StoryModel story;
  const _TextStory({required this.story});

  @override
  Widget build(BuildContext context) {
    Widget background;

    if (story.gradientColors != null && story.gradientColors!.length >= 2) {
      background = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: story.gradientColors!,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    } else {
      background = Container(
        color: story.backgroundColor ?? Colors.black,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        ...story.textOverlays.map(
          (overlay) => Positioned(
            left: overlay.position.dx,
            top: overlay.position.dy,
            child: Transform.rotate(
              angle: overlay.rotation,
              child: Text(
                overlay.text,
                style: overlay.style.copyWith(
                  color: overlay.color,
                  fontSize: overlay.fontSize,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
