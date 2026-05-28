import 'package:flutter/material.dart';
import '../models/story_model.dart';

class StoryTextOverlayWidget extends StatelessWidget {
  final StoryTextOverlay overlay;

  const StoryTextOverlayWidget({
    super.key,
    required this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: overlay.position.dx,
      top: overlay.position.dy,
      child: Transform.rotate(
        angle: overlay.rotation,
        child: Transform.scale(
          scale: overlay.scale,
          child: Container(
            padding: overlay.backgroundColor != Colors.transparent
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: overlay.backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              overlay.text,
              style: overlay.style.copyWith(
                color: overlay.color,
                fontSize: overlay.fontSize,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
