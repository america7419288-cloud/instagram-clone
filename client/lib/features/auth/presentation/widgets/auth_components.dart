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
class AuthGradientBackground extends StatelessWidget {
  final Widget child;
  const AuthGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
          colors: [
            Color(0xFFFFF0F5),
            Color(0xFFF4F0FF),
            Color(0xFFEFF6FF),
          ],
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────
// AUTH LOGO (SVG)
// ─────────────────────────────────────────────────────
class AuthLogo extends StatelessWidget {
  final double width;
  final Color? color;
  const AuthLogo({super.key, this.width = 180, this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/instagram_logo.svg',
      width: width,
      colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
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

  Color get _borderColor {
    if (widget.errorBorderColor != null) return widget.errorBorderColor!;
    if (widget.successBorderColor != null) return widget.successBorderColor!;
    if (widget.errorText != null) return AuthColors.errorRed;
    if (_hasFocus) return AuthColors.fieldFocused;
    return AuthColors.fieldBorder;
  }

  Widget? _buildSuffix() {
    if (widget.isLoading) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation(AuthColors.greyText),
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
          color: AuthColors.greyText, size: 20,
        ),
        onPressed: widget.onToggleVisibility ?? () => setState(() => _internalObscure = !_internalObscure),
      );
    }
    if (widget.controller.text.isNotEmpty && _hasFocus && widget.onClear != null) {
      return IconButton(
        icon: const Icon(Icons.cancel, color: AuthColors.greyText, size: 18),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AuthColors.white,
            borderRadius: BorderRadius.circular(AuthDimens.fieldRadius),
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: TextField(
            controller:      widget.controller,
            focusNode:       _focusNode,
            obscureText:     widget.isPassword && (widget.obscureText ?? _internalObscure),
            keyboardType:    widget.keyboardType,
            textInputAction: widget.textInputAction,
            enabled:         widget.isEnabled,
            maxLength:       widget.maxLength,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: (v) {
              setState(() {});
              widget.onChanged?.call(v);
            },
            onSubmitted: widget.onSubmitted,
            style: const TextStyle(
              fontSize: 14,
              color: AuthColors.darkText,
            ),
            decoration: InputDecoration(
              labelText:       widget.hintText ?? widget.placeholder,
              labelStyle:      const TextStyle(
                color: AuthColors.greyText, fontSize: 14,
              ),
              floatingLabelStyle: const TextStyle(
                color: AuthColors.greyText, fontSize: 12,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              contentPadding:  const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14,
              ),
              border:          InputBorder.none,
              suffixIcon:      _buildSuffix(),
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
            const Center(child: AuthLogo(width: 170)),
            const SizedBox(height: 32),
          ],
          const SizedBox(height: 12),
          AuthStepHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 32),
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
    return SizedBox(
      width: double.infinity,
      height: AuthDimens.btnHeight,
      child: ElevatedButton(
        onPressed: active ? () {
          HapticFeedback.lightImpact();
          onPressed!();
        } : null,
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
    );
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
    return SizedBox(
      width: double.infinity,
      height: AuthDimens.btnHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AuthColors.fieldBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuthDimens.btnRadius),
          ),
          backgroundColor: Colors.white.withAlpha(150),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor ?? AuthColors.blue,
            fontSize: AuthDimens.btnFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
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
    return GestureDetector(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuthDimens.hPad,
                    ),
                    child: child,
                  ),
                ),
                if (bottomWidget != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AuthDimens.hPad, 0, AuthDimens.hPad, 16,
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
    return IconButton(
      icon: const Icon(
        Icons.arrow_back_ios,
        color: AuthColors.darkText,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: AuthDimens.titleSize,
            fontWeight: FontWeight.bold,
            color: AuthColors.darkText,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: AuthDimens.subtitleSize,
              color: AuthColors.greyText,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
