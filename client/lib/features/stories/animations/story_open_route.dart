import 'package:flutter/material.dart';

class StoryOpenRoute extends PageRouteBuilder {
  final Widget child;
  final Rect? sourceRect; // position of tapped avatar
  final Color? dominantColor;

  StoryOpenRoute({
    required this.child,
    this.sourceRect,
    this.dominantColor,
  }) : super(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          opaque: false,
          barrierColor: Colors.transparent,
          pageBuilder: (_, __, ___) => child,
        );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final size = MediaQuery.of(context).size;

    if (sourceRect == null) {
      // Fallback: simple fade+scale
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      );
    }

    // Full screen target rect
    final targetRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Rect tween: from avatar position to full screen
    final rectTween = RectTween(
      begin: sourceRect,
      end: targetRect,
    );

    // Border radius tween: circle → rectangle
    final borderRadiusTween = BorderRadiusTween(
      begin: BorderRadius.circular(sourceRect!.width / 2),
      end: BorderRadius.zero,
    );

    // Curved animations
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.fastEaseInToSlowEaseOut,
    );

    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.55, 1.0, curve: Curves.easeIn),
    );

    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, _) {
        final rect = rectTween.evaluate(curvedAnimation)!;
        final borderRadius = borderRadiusTween.evaluate(curvedAnimation)!;

        return Stack(
          children: [
            // Dark scrim behind
            Positioned.fill(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.4),
                ),
                child: Container(color: Colors.black),
              ),
            ),
            // Expanding clip
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: ClipRRect(
                borderRadius: borderRadius,
                child: FadeTransition(
                  opacity: fadeAnimation,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Helper to navigate with animation
void openStoryViewer({
  required BuildContext context,
  required GlobalKey avatarKey,
  required Widget viewer,
}) {
  // Get avatar position
  final renderBox =
      avatarKey.currentContext?.findRenderObject() as RenderBox?;
  Rect? sourceRect;

  if (renderBox != null) {
    final position = renderBox.localToGlobal(Offset.zero);
    sourceRect = Rect.fromLTWH(
      position.dx,
      position.dy,
      renderBox.size.width,
      renderBox.size.height,
    );
  }

  Navigator.of(context).push(
    StoryOpenRoute(
      child: viewer,
      sourceRect: sourceRect,
    ),
  );
}
