// lib/core/widgets/app_buttons.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../theme/ios_colors.dart';
import '../theme/app_theme.dart'; // import to resolve .ms duration extensions

// ── Primary Button ──
class AppPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isFullWidth;
  final double height;
  final IconData? icon;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 44,
    this.icon,
  });

  @override
  State<AppPrimaryButton> createState() => _AppPrimaryButtonState();
}

class _AppPrimaryButtonState extends State<AppPrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null && !widget.isLoading;
    return GestureDetector(
      onTapDown: isEnabled ? (_) => _ctrl.forward() : null,
      onTapUp: isEnabled
        ? (_) {
            _ctrl.reverse();
            HapticFeedback.lightImpact();
            widget.onTap!();
          }
        : null,
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.height,
          width: widget.isFullWidth ? double.infinity : null,
          padding: widget.isFullWidth
            ? null
            : const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isEnabled
              ? IosColors.igBlue
              : IosColors.igBlue.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

// ── Secondary (Ghost) Button ──
class AppSecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? borderColor;

  const AppSecondaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.borderColor,
  });

  @override
  State<AppSecondaryButton> createState() => _AppSecondaryButtonState();
}

class _AppSecondaryButtonState extends State<AppSecondaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null
        ? (_) => _ctrl.forward()
        : null,
      onTapUp: widget.onTap != null
        ? (_) {
            _ctrl.reverse();
            HapticFeedback.lightImpact();
            widget.onTap!();
          }
        : null,
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.96).animate(_ctrl),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.borderColor
                ?? IosColors.separator(context),
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: IosColors.primary(context),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Icon Button (round, for toolbars) ──
class AppIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? color;
  final bool showBadge;
  final int badgeCount;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 24,
    this.color,
    this.showBadge = false,
    this.badgeCount = 0,
  });

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.85).animate(_ctrl),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                widget.icon,
                size: widget.size,
                color: widget.color ?? IosColors.primary(context),
              ),
            ),
            if (widget.showBadge)
              Positioned(
                top: 4,
                right: 4,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  builder: (_, v, __) => Transform.scale(
                    scale: v,
                    child: Container(
                      width: widget.badgeCount > 9 ? 20 : 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: IosColors.igRed,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: IosColors.background(context),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.badgeCount > 99
                          ? '99+'
                          : widget.badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Like Button ──
class AppLikeButton extends StatefulWidget {
  final bool isLiked;
  final int count;
  final Function(bool) onChanged;

  const AppLikeButton({
    super.key,
    required this.isLiked,
    required this.count,
    required this.onChanged,
  });

  @override
  State<AppLikeButton> createState() => _AppLikeButtonState();
}

class _AppLikeButtonState extends State<AppLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late bool _liked;
  late int _count;

  @override
  void initState() {
    super.initState();
    _liked = widget.isLiked;
    _count = widget.count;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35), weight: 30),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 0.9), weight: 20),
      TweenSequenceItem(
        tween: Tween(begin: 0.9, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      _count += _liked ? 1 : -1;
    });
    _ctrl.forward(from: 0);
    widget.onChanged(_liked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: child,
              ),
              child: Icon(
                _liked
                  ? CupertinoIcons.heart_fill
                  : CupertinoIcons.heart,
                key: ValueKey(_liked),
                size: 24,
                color: _liked
                  ? IosColors.igRed
                  : IosColors.primary(context),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _AnimatedCountText(count: _count),
        ],
      ),
    );
  }
}

class _AnimatedCountText extends StatefulWidget {
  final int count;
  const _AnimatedCountText({required this.count});

  @override
  State<_AnimatedCountText> createState() => _AnimatedCountTextState();
}

class _AnimatedCountTextState extends State<_AnimatedCountText> {
  late int _displayed;
  late int _previous;

  @override
  void initState() {
    super.initState();
    _displayed = widget.count;
    _previous = widget.count;
  }

  @override
  void didUpdateWidget(_AnimatedCountText old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) {
      _previous = old.count;
      _displayed = widget.count;
    }
  }

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) {
        final goingUp = _displayed > _previous;
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, goingUp ? 0.5 : -0.5),
            end: Offset.zero,
          ).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      child: Text(
        _format(_displayed),
        key: ValueKey(_displayed),
        style: TextStyle(
          color: IosColors.primary(context),
          fontSize: 14,
          fontWeight: FontWeight.w400,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
