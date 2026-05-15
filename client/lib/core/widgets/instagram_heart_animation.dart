import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class InstagramHeartAnimation extends StatefulWidget {
  final Widget child;
  final bool isAnimating;
  final Duration duration;
  final VoidCallback onEnd;
  final bool isSmall;

  const InstagramHeartAnimation({
    super.key,
    required this.child,
    required this.isAnimating,
    this.duration = const Duration(milliseconds: 700),
    required this.onEnd,
    this.isSmall = false,
  });

  @override
  State<InstagramHeartAnimation> createState() => _InstagramHeartAnimationState();
}

class _InstagramHeartAnimationState extends State<InstagramHeartAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _rotation;
  late Animation<double> _opacity;
  late Animation<double> _translation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.2),
        weight: 55.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 20.0,
      ),
    ]).animate(_controller);

    _translation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -20.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -20.0, end: -45.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 55.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -45.0, end: -60.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 20.0,
      ),
    ]).animate(_controller);

    _rotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.15, end: 0.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.15, end: -0.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.1, end: 0.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10.0,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 30.0,
      ),
    ]).animate(_controller);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0).chain(CurveTween(curve: Curves.linear)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_controller);

    if (widget.isAnimating) {
      _controller.forward().then((_) {
        if (mounted) widget.onEnd();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.translate(
                offset: Offset(0, _translation.value),
                child: Transform.rotate(
                  angle: _rotation.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: const BrandedHeartIcon(size: 80),
        ),
      ],
    );
  }
}

class BrandedHeartIcon extends StatelessWidget {
  final double size;

  const BrandedHeartIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
     //from project_aura_superlikeheart.xml
    const String pathData =
        "M17.07533,1.9867c-2.14628,0 -3.80474,0.87041 -5.07014,2.66098c-0.00277,0.00392 -0.00551,0.00779 -0.00827,0.01171c-0.00341,-0.00478 -0.00681,-0.00955 -0.01024,-0.01435c-1.27847,-1.78879 -2.93427,-2.65835 -5.062,-2.65835C3.3821,1.9867 0.5,5.11111 0.5,8.95155c0,3.5141 2.5811,5.75768 5.07722,7.92738c0.30172,0.26226 0.60651,0.52716 0.91014,0.79703l1.08845,0.97344c2.11183,1.89021 3.14886,2.81301 3.64263,3.13288c0.23775,0.15401 0.50966,0.23103 0.78156,0.23103s0.54377,-0.077 0.78153,-0.231c0.47279,-0.30628 1.33423,-1.0703 3.75553,-3.23449l0.97821,-0.874c0.31369,-0.27904 0.63097,-0.55426 0.94499,-0.8267c2.47769,-2.14964 5.03974,-4.37245 5.03974,-7.89556c0,-3.84044 -2.88209,-6.96485 -6.42467,-6.96485h0Z";

    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white" xmlns="http://www.w3.org/2000/svg">
        <path d="$pathData" fill="white"/>
      </svg>''',
      width: size,
      height: size,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }
}
