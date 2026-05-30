// lib/features/auth/presentation/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_components.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _identifierFocus= FocusNode();
  final _passwordFocus  = FocusNode();

  String? _identifierError;
  String? _passwordError;
  String? _serverError;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _identifierFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    bool ok = true;
    setState(() {
      _identifierError = _passwordError = null;
      if (_identifierCtrl.text.trim().isEmpty) {
        _identifierError = 'Please enter your username or email';
        ok = false;
      }
      if (_passwordCtrl.text.isEmpty) {
        _passwordError = 'Please enter your password';
        ok = false;
      }
    });
    return ok;
  }

  Future<void> _handleLogin() async {
    if (!_validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _serverError = null);

    try {
      final success = await ref.read(authProvider.notifier).login(
        identifier: _identifierCtrl.text.trim(),
        password:   _passwordCtrl.text,
      );
      if (success && mounted) context.go(AppRoutes.home);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        if (msg.toLowerCase().contains('credential') ||
            msg.toLowerCase().contains('password') ||
            msg.toLowerCase().contains('invalid')) {
          _passwordError = msg;
        } else {
          _serverError = msg;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return AuthScreenWrapper(
      showBack: false,
      bottomWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthSecondaryButton(
            text: 'Create new account',
            textColor: AuthColors.blue,
            onPressed: () => context.push(AppRoutes.register),
          ),
          const SizedBox(height: 12),
          const Text(
            'Meta',
            style: TextStyle(
              color: AuthColors.greyText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
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

          // ─── IDENTIFIER ─────────────────────
          AuthEntrance(
            delay: const Duration(milliseconds: 80),
            child: AuthTextField(
              placeholder:     'Username, email or mobile number',
              controller:      _identifierCtrl,
              focusNode:       _identifierFocus,
              keyboardType:    TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText:       _identifierError,
              onChanged: (_) => setState(() {
                _identifierError = null;
                _serverError = null;
              }),
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
          ),

          const SizedBox(height: 12),

          // ─── PASSWORD ───────────────────────
          AuthEntrance(
            delay: const Duration(milliseconds: 120),
            child: AuthTextField(
              placeholder:     'Password',
              controller:      _passwordCtrl,
              focusNode:       _passwordFocus,
              isPassword:      true,
              textInputAction: TextInputAction.done,
              errorText:       _passwordError,
              onChanged: (_) => setState(() {
                _passwordError = null;
                _serverError   = null;
              }),
              onSubmitted: (_) => _handleLogin(),
            ),
          ),

          const SizedBox(height: 12),

          // ─── SERVER ERROR ───────────────────
          if (_serverError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: AuthColors.errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AuthColors.errorRed.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _serverError!,
                style: const TextStyle(
                  color: AuthColors.errorRed,
                  fontSize: 13,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ─── LOGIN BUTTON ───────────────────
          AuthEntrance(
            delay: const Duration(milliseconds: 160),
            child: AuthPrimaryButton(
              text:      'Log in',
              isLoading: isLoading,
              onPressed: isLoading ? null : _handleLogin,
            ),
          ),

          const SizedBox(height: 16),

          // ─── FORGOT PASSWORD ────────────────
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: _showForgotPasswordSheet,
              child: Text(
                'Forgot password?',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AuthColors.darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ─── OR DIVIDER ─────────────────────
          Row(children: [
            Expanded(child: Divider(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : AuthColors.fieldBorder)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR',
                style: TextStyle(
                  color: AuthColors.greyText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(child: Divider(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : AuthColors.fieldBorder)),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ForgotPasswordSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────
// FORGOT PASSWORD SHEET
// ─────────────────────────────────────────────────────
class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your username or email');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Mock API delay
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(seconds: 2000));
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPad),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: _isSuccess ? _buildSuccessState(isDark) : _buildFormState(isDark),
      ),
    );
  }

  Widget _buildSuccessState(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Link Sent',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We've sent a login link to ${_emailCtrl.text.trim()}.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFormState(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag Handle
        Center(
          child: Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Trouble logging in?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Enter your email or username and we'll send you a link to get back into your account.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        AuthTextField(
          hintText: 'Email or username',
          controller: _emailCtrl,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          errorText: _error,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _handleReset(),
        ),
        const SizedBox(height: 20),
        AuthPrimaryButton(
          text: 'Send login link',
          isLoading: _isLoading,
          onPressed: _handleReset,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
