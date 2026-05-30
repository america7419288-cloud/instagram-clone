// lib/features/auth/presentation/widgets/auth_components.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────
class AuthColors {
  AuthColors._();
  static const blue        = Color(0xFF3897F0);
  static const errorRed    = Color(0xFFED4956);
  static const successGreen= Color(0xFF2ECC71);
  static const fieldBorder = Color(0xFFDBDBDB);
  static const fieldFocused= Color(0xFF262626);
  static const greyText    = Color(0xFF8E8E8E);
  static const darkText    = Color(0xFF262626);
  static const metaGrey    = Color(0xFF8E8E8E);
  static const white       = Color(0xFFFFFFFF);
  static const bg          = Color(0xFFFAFAFA);
  static const fieldFill   = Color(0xFFF2F2F7);
}

class AuthDimens {
  AuthDimens._();
  static const hPad        = 8.0;
  static const btnHeight   = 50.0;
  static const btnRadius   = 12.0;
  static const fieldRadius = 12.0;
  static const titleSize   = 24.0;
  static const subtitleSize= 14.0;
  static const btnFontSize = 15.0;
}

// ─────────────────────────────────────────────────────
// GRADIENT BACKGROUND
// ─────────────────────────────────────────────────────
class AuthGradientBackground extends StatefulWidget {
  final Widget child;
  const AuthGradientBackground({super.key, required this.child});

  @override
  State<AuthGradientBackground> createState() => _AuthGradientBackgroundState();
}

class _AuthGradientBackgroundState extends State<AuthGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 40),
      vsync: this,
    )..repeat(reverse: true);

    _topAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.topRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.topRight, end: Alignment.bottomRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.bottomLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.bottomLeft, end: Alignment.topLeft),
        weight: 1,
      ),
    ]).animate(_controller);

    _bottomAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.bottomLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.bottomLeft, end: Alignment.topLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.topRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.topRight, end: Alignment.bottomRight),
        weight: 1,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [
            Color(0xFF0C1014), // Prism Black
            Color(0xFF1C0D24), // Rich dark purple
            Color(0xFF0B1B26), // Rich dark blue
            Color(0xFF141026), // Rich dark indigo
          ]
        : const [
            Color(0xFFFDF2F4), // Very Light Pink
            Color(0xFFF5EEF8), // Very Light Purple
            Color(0xFFFEF9E7), // Very Light Yellow
            Color(0xFFF0F4FF), // Very Light Blue
          ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _topAlignmentAnimation.value,
              end: _bottomAlignmentAnimation.value,
              colors: gradientColors,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
// AUTH LOGO (SVG)
// ─────────────────────────────────────────────────────
class AuthLogo extends StatelessWidget {
  final double width;
  final Color? color;
  const AuthLogo({super.key, this.width = 70, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalColor = color ?? (isDark ? Colors.white : Colors.black);
    return SvgPicture.asset(
      'assets/images/instagram_logo.svg',
      width: width,
      colorFilter: ColorFilter.mode(finalColor, BlendMode.srcIn),
    );
  }
}

// ─────────────────────────────────────────────────────
// AUTH TEXT FIELD
// ─────────────────────────────────────────────────────
class AuthTextField extends StatefulWidget {
  final String? hintText;
  final String? placeholder; // For backward compatibility
  final TextEditingController controller;
  final bool isPassword;
  final bool isEnabled;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? errorText;
  final Widget? suffixIcon;
  final Widget? statusIcon; // New: alias for suffixIcon or used separately
  final bool isLoading;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final int? maxLength;
  final Color? successBorderColor;
  final Color? errorBorderColor;
  final bool? obscureText; // New: external control
  final VoidCallback? onToggleVisibility; // New: external control
  final List<TextInputFormatter>? inputFormatters;

  const AuthTextField({
    super.key,
    this.hintText,
    this.placeholder,
    required this.controller,
    this.isPassword     = false,
    this.isEnabled      = true,
    this.keyboardType   = TextInputType.text,
    this.textInputAction= TextInputAction.next,
    this.errorText,
    this.suffixIcon,
    this.statusIcon,
    this.isLoading      = false,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.focusNode,
    this.maxLength,
    this.successBorderColor,
    this.errorBorderColor,
    this.obscureText,
    this.onToggleVisibility,
    this.inputFormatters,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _internalObscure = true;
  bool _hasFocus = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  Color _borderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.errorBorderColor != null) return widget.errorBorderColor!;
    if (widget.successBorderColor != null) return widget.successBorderColor!;
    if (widget.errorText != null) return AuthColors.errorRed;
    if (_hasFocus) {
      return isDark ? Colors.white70 : AuthColors.fieldFocused;
    }
    return isDark ? Colors.white12 : AuthColors.fieldBorder;
  }

  Widget? _buildSuffix(bool isDark) {
    if (widget.isLoading) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(isDark ? Colors.white60 : AuthColors.greyText),
          ),
        ),
      );
    }
    if (widget.statusIcon != null) return widget.statusIcon;
    if (widget.suffixIcon != null) return widget.suffixIcon;
    if (widget.isPassword) {
      final obscure = widget.obscureText ?? _internalObscure;
      return IconButton(
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: isDark ? Colors.white60 : AuthColors.greyText, size: 20,
        ),
        onPressed: widget.onToggleVisibility ?? () => setState(() => _internalObscure = !_internalObscure),
      );
    }
    if (widget.controller.text.isNotEmpty && _hasFocus && widget.onClear != null) {
      return IconButton(
        icon: Icon(Icons.cancel, color: isDark ? Colors.white60 : AuthColors.greyText, size: 18),
        onPressed: () {
          widget.controller.clear();
          widget.onClear?.call();
        },
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldElevate = _hasFocus && widget.errorText == null;
    final fillCol = isDark ? Colors.white.withOpacity(0.06) : AuthColors.fieldFill;
    final borderCol = _borderColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: fillCol,
            borderRadius: BorderRadius.circular(AuthDimens.fieldRadius),
            border: Border.all(color: borderCol, width: 1),
            boxShadow: shouldElevate
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: TextField(
            controller:      widget.controller,
            focusNode:       _focusNode,
            obscureText:     widget.isPassword && (widget.obscureText ?? _internalObscure),
            keyboardType:    widget.keyboardType,
            textInputAction: widget.textInputAction,
            enabled:         widget.isEnabled,
            maxLength:       widget.maxLength,
            inputFormatters: widget.inputFormatters,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: (v) {
              setState(() {});
              widget.onChanged?.call(v);
            },
            onSubmitted: widget.onSubmitted,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : AuthColors.darkText,
            ),
            decoration: InputDecoration(
              labelText:       widget.hintText ?? widget.placeholder,
              labelStyle:      TextStyle(
                color: isDark ? Colors.white38 : AuthColors.greyText, fontSize: 14,
              ),
              floatingLabelStyle: TextStyle(
                color: isDark ? Colors.white54 : AuthColors.greyText, fontSize: 12,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              contentPadding:  const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14,
              ),
              filled: true,
              fillColor: Colors.transparent,
              border:          InputBorder.none,
              suffixIcon:      _buildSuffix(isDark),
            ),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                color: AuthColors.errorRed,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
// AUTH SCAFFOLD
// ─────────────────────────────────────────────────────
class AuthScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> body;
  final Widget? footer;
  final bool showBack;
  final bool showLogo;
  final VoidCallback? onBack;

  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.footer,
    this.showBack = true,
    this.showLogo = true,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return AuthScreenWrapper(
      showBack: showBack,
      onBack: onBack,
      bottomWidget: footer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLogo) ...[
            const Center(child: AuthLogo(width: 70)),
            const SizedBox(height: 50),
          ],
          const SizedBox(height: 12),
          AuthStepHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 70),
          ...body,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// PRIMARY BUTTON
// ─────────────────────────────────────────────────────
class AuthPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;

  const AuthPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading  = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = !isDisabled && !isLoading && onPressed != null;
    return _Pressable(
      enabled: active,
      onTap: onPressed,
      child: SizedBox(
      width: double.infinity,
      height: AuthDimens.btnHeight,
      child: ElevatedButton(
        onPressed: active
            ? () {
                HapticFeedback.lightImpact();
                onPressed?.call();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: active
              ? AuthColors.blue
              : AuthColors.blue.withAlpha(128),
          foregroundColor: Colors.white,
          disabledBackgroundColor: AuthColors.blue.withAlpha(100),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuthDimens.btnRadius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: AuthDimens.btnFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────
// SECONDARY BUTTON
// ─────────────────────────────────────────────────────
class AuthSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? textColor;

  const AuthSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _Pressable(
      enabled: onPressed != null,
      onTap: onPressed,
      child: SizedBox(
      width: double.infinity,
      height: AuthDimens.btnHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isDark ? Colors.white12 : AuthColors.fieldBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuthDimens.btnRadius),
          ),
          backgroundColor: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withAlpha(150),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor ?? (isDark ? Colors.white : AuthColors.blue),
            fontSize: AuthDimens.btnFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────
// ALREADY HAVE ACCOUNT LINK
// ─────────────────────────────────────────────────────
class AuthAlreadyHaveAccount extends StatelessWidget {
  final VoidCallback onTap;
  const AuthAlreadyHaveAccount({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      enabled: true,
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'I already have an account',
          style: TextStyle(
            color: AuthColors.blue,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// SCREEN WRAPPER (gradient bg + safe area + scroll)
// ─────────────────────────────────────────────────────
class AuthScreenWrapper extends StatelessWidget {
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? bottomWidget;

  const AuthScreenWrapper({
    super.key,
    required this.child,
    this.showBack     = true,
    this.onBack,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    return AuthGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: Column(
              children: [
                if (showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CupertinoBackButton(onBack: onBack ?? () => Navigator.of(context).pop()),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuthDimens.hPad,
                    ),
                    child: child,
                  ),
                ),
                if (bottomWidget != null && MediaQuery.of(context).viewInsets.bottom == 0)
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.fromLTRB(
                      AuthDimens.hPad,
                      0,
                      AuthDimens.hPad,
                      16,
                    ),
                    child: bottomWidget!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// CUPERTINO BACK BUTTON
// ─────────────────────────────────────────────────────
class CupertinoBackButton extends StatelessWidget {
  final VoidCallback onBack;
  const CupertinoBackButton({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(
        Icons.arrow_back_ios,
        color: isDark ? Colors.white : AuthColors.darkText,
        size: 22,
      ),
      onPressed: onBack,
      padding: const EdgeInsets.all(12),
    );
  }
}

// ─────────────────────────────────────────────────────
// STEP TITLE + SUBTITLE
// ─────────────────────────────────────────────────────
class AuthStepHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const AuthStepHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AuthDimens.titleSize,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AuthColors.darkText,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: AuthDimens.subtitleSize,
              color: isDark ? Colors.white54 : AuthColors.greyText,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class AuthEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double beginOffsetY;

  const AuthEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.delay = Duration.zero,
    this.beginOffsetY = 0.04,
  });

  @override
  State<AuthEntrance> createState() => _AuthEntranceState();
}

class _AuthEntranceState extends State<AuthEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : Offset(0, widget.beginOffsetY),
        child: widget.child,
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  const _Pressable({
    required this.child,
    required this.onTap,
    required this.enabled,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap?.call();
            }
          : null,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    ));
  }
}
