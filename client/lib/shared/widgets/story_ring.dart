// lib/shared/widgets/story_ring.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class StoryRing extends StatefulWidget {
  final bool hasUnseen;
  final Widget child;
  final double size;
  final bool isLoading;

  const StoryRing({
    super.key,
    required this.hasUnseen,
    required this.child,
    this.size = 64,
    this.isLoading = false,
  });

  @override
  State<StoryRing> createState() => _StoryRingState();
}

class _StoryRingState extends State<StoryRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void didUpdateWidget(StoryRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _controller.duration = const Duration(milliseconds: 800);
      _controller.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _controller.duration = const Duration(seconds: 8);
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final ringPadding = widget.size * 0.04;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: EdgeInsets.all(ringPadding),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.hasUnseen
                  ? SweepGradient(
                      transform: GradientRotation(_controller.value * 2 * math.pi),
                      colors: const [
                        Color(0xFFF9CE34),
                        Color(0xFFEE2A7B),
                        Color(0xFF6228D7),
                        Color(0xFFF9CE34),
                      ],
                    )
                  : SweepGradient(
                      colors: [
                        isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
                        isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
                      ],
                    ),
            ),
            child: Container(
              padding: EdgeInsets.all(ringPadding),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(child: widget.child),
            ),
          );
        },
      ),
    );
  }
}
