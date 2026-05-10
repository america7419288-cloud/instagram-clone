// lib/features/auth/presentation/pages/register_page.dart
//
// Entry point for the multi-step signup wizard.
// GoRouter mounts /register → RegisterPage.
// All internal steps are pushed on the NestedNavigator below.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../providers/signup_provider.dart';
import '../widgets/auth_components.dart';
import 'signup/step2_fullname_screen.dart';

class RegisterPage extends ConsumerWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _EmailStep();
  }
}

// ─────────────────────────────────────────────────────
// STEP 1 – EMAIL
// ─────────────────────────────────────────────────────
class _EmailStep extends ConsumerStatefulWidget {
  const _EmailStep();

  @override
  ConsumerState<_EmailStep> createState() => _EmailStepState();
}

class _EmailStepState extends ConsumerState<_EmailStep> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();

  Timer?  _debounce;
  bool    _isChecking  = false;
  bool?   _isAvailable;
  String? _errorText;
  bool    _usePhone    = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isEmail =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_ctrl.text.trim());

  bool get _isPhone =>
      RegExp(r'^\+?\d{7,15}$').hasMatch(_ctrl.text.trim().replaceAll(' ', ''));

  bool get _isValid => _usePhone ? _isPhone : _isEmail;

  bool get _canNext =>
      _isValid && !_isChecking && (_usePhone || _isAvailable == true);

  void _onChanged(String v) {
    setState(() {
      _isAvailable = null;
      _errorText   = null;
    });
    _debounce?.cancel();
    if (!_usePhone && _isEmail) {
      setState(() => _isChecking = true);
      _debounce = Timer(const Duration(milliseconds: 700), _checkEmail);
    }
  }

  Future<void> _checkEmail() async {
    setState(() => _isChecking = true);
    try {
      final result = await ref
          .read(signupProvider.notifier)
          .checkEmail(_ctrl.text.trim());
      if (mounted) {
        setState(() {
          _isChecking  = false;
          _isAvailable = result;
          _errorText   = result ? null : 'This email is already in use.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _next() {
    if (!_canNext) return;
    FocusScope.of(context).unfocus();
    if (_usePhone) {
      ref.read(signupProvider.notifier).setPhone(_ctrl.text.trim());
    } else {
      ref.read(signupProvider.notifier).setEmail(_ctrl.text.trim());
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const Step2FullNameScreen()),
    );
  }

  Widget? _suffixIcon() {
    if (_isChecking) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AuthColors.greyText)),
        ),
      );
    }
    if (_isAvailable == true && _isEmail) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Icon(Icons.check_circle, color: AuthColors.successGreen, size: 20),
      );
    }
    if (_isAvailable == false) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Icon(Icons.cancel, color: AuthColors.errorRed, size: 20),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenWrapper(
      showBack: false,
      bottomWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthPrimaryButton(
            text: 'Next',
            isDisabled: !_canNext,
            onPressed: _canNext ? _next : null,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _usePhone    = !_usePhone;
                _ctrl.clear();
                _isAvailable = null;
                _errorText   = null;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _usePhone
                    ? 'Use email address instead'
                    : 'Use phone number instead',
                style: const TextStyle(
                  color: AuthColors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => context.go(AppRoutes.login),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text.rich(TextSpan(children: [
                TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(color: AuthColors.greyText, fontSize: 13),
                ),
                TextSpan(
                  text: 'Log in',
                  style: TextStyle(
                    color: AuthColors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ])),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 60),
          const AuthEntrance(
            child: Center(child: AuthLogo(width: 70)),
          ),
          const SizedBox(height: 110),

          AuthEntrance(
            delay: const Duration(milliseconds: 80),
            child: AuthStepHeader(
              title: _usePhone
                  ? "What's your mobile number?"
                  : "What's your email address?",
              subtitle: _usePhone
                  ? 'Enter the mobile number at which you can be reached.'
                  : 'Enter the email address at which you can be reached.\nNo one will see this on your profile.',
            ),
          ),

          const SizedBox(height: 24),

          AuthEntrance(
            delay: const Duration(milliseconds: 130),
            child: AuthTextField(
              placeholder:  _usePhone ? 'Mobile number' : 'Email address',
              controller:   _ctrl,
              focusNode:    _focus,
              keyboardType: _usePhone
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText:    _errorText,
              suffixIcon:   _suffixIcon(),
              onChanged:    _onChanged,
              onClear: () => setState(() {
                _isAvailable = null;
                _errorText   = null;
              }),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
