// lib/core/router/ios_page_route.dart
//
// iOS-exact page transition for GoRouter.
// Push  → 400 ms, new page slides RIGHT→LEFT, old page shifts LEFT by 33 %
// Pop   → 350 ms, reverse
// Edge-swipe-to-go-back included via SwipeBackWrapper.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ─── iOS timing curves ─────────────────────────────────────────
const _kIOSCurve = Cubic(0.25, 0.1, 0.25, 1.0); // matches UIKit
const _kPushDuration = Duration(milliseconds: 400);
const _kPopDuration = Duration(milliseconds: 350);
const _kParallaxFactor = 0.33; // old page shifts 33 % left on push
const _kShadowWidth = 12.0;

// ─── Factory ────────────────────────────────────────────────────
/// Wraps [child] in a CustomTransitionPage with iOS-exact slide
/// transition + optional swipe-back gesture.
CustomTransitionPage<T> iosPage<T>({
  required GoRouterState state,
  required Widget child,
  bool enableSwipeBack = true,
}) {
  final wrappedChild =
      enableSwipeBack ? SwipeBackWrapper(child: child) : child;

  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: wrappedChild,
    transitionDuration: _kPushDuration,
    reverseTransitionDuration: _kPopDuration,
    transitionsBuilder: _iosTransitionsBuilder,
  );
}

// ─── Transition builder ─────────────────────────────────────────
Widget _iosTransitionsBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final screenWidth = MediaQuery.of(context).size.width;

  // Primary animation — the INCOMING page
  final primaryOffset = Tween<Offset>(
    begin: Offset(screenWidth, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: animation, curve: _kIOSCurve));

  // Secondary animation — the OUTGOING page (parallax shift left)
  final secondaryOffset = Tween<Offset>(
    begin: Offset.zero,
    end: Offset(-screenWidth * _kParallaxFactor, 0),
  ).animate(CurvedAnimation(parent: secondaryAnimation, curve: _kIOSCurve));

  // Shadow that appears on the left edge of the incoming page
  final shadowOpacity = Tween<double>(begin: 0.0, end: 0.15).animate(
    CurvedAnimation(parent: animation, curve: _kIOSCurve),
  );

  // Slight dim on the outgoing page
  final dimOpacity = Tween<double>(begin: 0.0, end: 0.08).animate(
    CurvedAnimation(parent: secondaryAnimation, curve: _kIOSCurve),
  );

  return Stack(
    children: [
      // ── Outgoing page (shifts left) + dim overlay ──
      AnimatedBuilder(
        animation: secondaryAnimation,
        builder: (_, outChild) {
          return Transform.translate(
            offset: secondaryOffset.value,
            child: Stack(
              children: [
                outChild!,
                // Dim overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: dimOpacity.value),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: const SizedBox.shrink(), // placeholder; secondary child is parent
      ),

      // ── Incoming page (slides from right) ──
      AnimatedBuilder(
        animation: animation,
        builder: (_, inChild) {
          return Transform.translate(
            offset: primaryOffset.value,
            child: Stack(
              children: [
                inChild!,
                // Left-edge shadow
                Positioned(
                  left: -_kShadowWidth,
                  top: 0,
                  bottom: 0,
                  width: _kShadowWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.black.withValues(alpha: shadowOpacity.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: child,
      ),
    ],
  );
}

// ─── Swipe-back wrapper ─────────────────────────────────────────
class SwipeBackWrapper extends StatefulWidget {
  const SwipeBackWrapper({super.key, required this.child});
  final Widget child;

  @override
  State<SwipeBackWrapper> createState() => _SwipeBackWrapperState();
}

class _SwipeBackWrapperState extends State<SwipeBackWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dragController;
  double _dragOffset = 0;
  bool _isDragging = false;
  bool _thresholdCrossed = false;

  static const _edgeWidth = 20.0;
  static const _thresholdFraction = 0.35;

  @override
  void initState() {
    super.initState();
    _dragController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (details.globalPosition.dx > _edgeWidth) return;
    if (!Navigator.of(context).canPop()) return;
    setState(() {
      _isDragging = true;
      _dragOffset = 0;
      _thresholdCrossed = false;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, screenWidth);
    });

    final fraction = _dragOffset / screenWidth;
    if (!_thresholdCrossed && fraction >= _thresholdFraction) {
      _thresholdCrossed = true;
      HapticFeedback.selectionClick();
    } else if (_thresholdCrossed && fraction < _thresholdFraction) {
      _thresholdCrossed = false;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final fraction = _dragOffset / screenWidth;
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (fraction >= _thresholdFraction || velocity > 800) {
      // Animate off-screen then pop
      _dragController.value = fraction;
      _dragController.animateTo(1.0, curve: _kIOSCurve).then((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      _dragController.addListener(_animListener);
    } else {
      // Snap back
      _dragController.value = fraction;
      _dragController.animateTo(0.0, curve: _kIOSCurve).then((_) {
        if (mounted) {
          setState(() {
            _isDragging = false;
            _dragOffset = 0;
          });
        }
      });
      _dragController.addListener(_animListener);
    }
  }

  void _animListener() {
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _dragOffset = _dragController.value * screenWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: _isDragging
          ? Stack(
              children: [
                // Shadow on the left edge
                Positioned(
                  left: _dragOffset - _kShadowWidth,
                  top: 0,
                  bottom: 0,
                  width: _kShadowWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.black.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Page content
                Transform.translate(
                  offset: Offset(_dragOffset, 0),
                  child: widget.child,
                ),
              ],
            )
          : widget.child,
    );
  }
}
