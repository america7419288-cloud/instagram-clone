// lib/features/notes/widgets/note_bubble_painter.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class NoteBubblePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double tailWidth;
  final double tailHeight;
  final bool isDashed;

  const NoteBubblePainter({
    required this.backgroundColor,
    required this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius = 12.0,
    this.tailWidth = 8.0,
    this.tailHeight = 6.0,
    this.isDashed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = _buildBubblePath(size);

    // 1. Draw beautiful soft box shadow
    canvas.drawShadow(
      path,
      Colors.black.withOpacity(0.06),
      4.0, // Elevation
      false, // Transparent occluder
    );

    // 2. Draw bubble fill
    canvas.drawPath(path, paint);

    // 3. Draw bubble border (Solid vs Dashing via PathMetric)
    if (isDashed) {
      final dashedPath = Path();
      const double dashWidth = 5.0;
      const double spaceWidth = 3.0;
      
      for (final PathMetric metric in path.computeMetrics()) {
        double distance = 0.0;
        while (distance < metric.length) {
          final double len = dashWidth;
          if (distance + len > metric.length) {
            dashedPath.addPath(
              metric.extractPath(distance, metric.length),
              Offset.zero,
            );
          } else {
            dashedPath.addPath(
              metric.extractPath(distance, distance + len),
              Offset.zero,
            );
          }
          distance += dashWidth + spaceWidth;
        }
      }
      canvas.drawPath(dashedPath, borderPaint);
    } else {
      canvas.drawPath(path, borderPaint);
    }
  }

  Path _buildBubblePath(Size size) {
    final double r = borderRadius;
    final double w = size.width;
    final double h = size.height - tailHeight;
    // Tail sits at the bottom-left of the bubble, pointing downwards
    const double tailX = 14.0; 

    return Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(tailX + tailWidth, h)
      // Triangle pointer tail pointing down
      ..lineTo(tailX + tailWidth / 2, h + tailHeight)
      ..lineTo(tailX, h)
      // Sharp bottom-left corner at 4px radius for the tail visual integration
      ..lineTo(4.0, h)
      ..quadraticBezierTo(0, h, 0, h - 4.0)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
  }

  @override
  bool shouldRepaint(NoteBubblePainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.tailWidth != tailWidth ||
        oldDelegate.tailHeight != tailHeight ||
        oldDelegate.isDashed != isDashed;
  }
}
