// lib/shared/widgets/like_particles.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

class LikeParticles extends StatefulWidget {
  final Offset position;

  const LikeParticles({super.key, required this.position});

  @override
  State<LikeParticles> createState() => _LikeParticlesState();
}

class _LikeParticlesState extends State<LikeParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ParticleData> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    final random = math.Random();
    for (int i = 0; i < 6; i++) {
      _particles.add(_ParticleData(
        angle: (random.nextDouble() * 2 - 1) * 0.5 - 1.57, // Upwards range
        velocity: 2.0 + random.nextDouble() * 2.0,
        size: 10.0 + random.nextDouble() * 10.0,
      ));
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: _particles.map((p) {
            final t = _controller.value;
            final dx = p.velocity * 100 * t * math.cos(p.angle);
            final dy = p.velocity * 100 * t * math.sin(p.angle);
            final opacity = (1.0 - t).clamp(0.0, 1.0);
            
            return Positioned(
              left: widget.position.dx + dx,
              top: widget.position.dy + dy,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: 0.5 + t * 0.5,
                  child: Container(
                    width: p.size,
                    height: p.size,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(204),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ParticleData {
  final double angle;
  final double velocity;
  final double size;

  _ParticleData({required this.angle, required this.velocity, required this.size});
}
