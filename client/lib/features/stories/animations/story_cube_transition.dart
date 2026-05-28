import 'package:flutter/material.dart';

class StoryCubeTransition extends StatelessWidget {
  final Widget currentChild;
  final Widget nextChild;
  final Animation<double> animation; // 0 = current, 1 = next
  final bool isForward;

  const StoryCubeTransition({
    super.key,
    required this.currentChild,
    required this.nextChild,
    required this.animation,
    required this.isForward,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;

        return Stack(
          children: [
            // Outgoing page
            _buildOutgoing(t),
            // Incoming page
            _buildIncoming(t),
          ],
        );
      },
    );
  }

  Widget _buildOutgoing(double t) {
    final angle = isForward ? -t * (3.14159 / 2) : t * (3.14159 / 2);
    final opacity = (1.0 - t * 1.2).clamp(0.0, 1.0);

    return Transform(
      alignment: isForward ? Alignment.centerRight : Alignment.centerLeft,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // perspective
        ..rotateY(angle),
      child: Opacity(
        opacity: opacity,
        child: currentChild,
      ),
    );
  }

  Widget _buildIncoming(double t) {
    final angle = isForward
        ? (1 - t) * (3.14159 / 2)
        : -(1 - t) * (3.14159 / 2);
    final opacity = (t * 1.2 - 0.2).clamp(0.0, 1.0);

    return Transform(
      alignment: isForward ? Alignment.centerLeft : Alignment.centerRight,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(angle),
      child: Opacity(
        opacity: opacity,
        child: nextChild,
      ),
    );
  }
}
