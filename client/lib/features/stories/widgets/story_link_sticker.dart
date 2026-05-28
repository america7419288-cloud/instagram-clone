import 'package:flutter/material.dart';
import '../models/story_model.dart';

class StoryLinkSticker extends StatelessWidget {
  final StoryLinkData link;
  final VoidCallback? onTap;

  const StoryLinkSticker({
    super.key,
    required this.link,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.link_rounded,
                color: Colors.blue,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                link.displayText.toUpperCase(),
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.blue,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
