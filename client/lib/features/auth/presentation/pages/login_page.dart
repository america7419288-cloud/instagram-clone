// lib/features/auth/presentation/pages/login_page.dart

import 'package:flutter/material.dart';
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
          const SizedBox(height: 40),
          const Center(child: AuthLogo(width: 170)),
          const SizedBox(height: 40),

          // ─── IDENTIFIER ─────────────────────
          AuthTextField(
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

          const SizedBox(height: 12),

          // ─── PASSWORD ───────────────────────
          AuthTextField(
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
          AuthPrimaryButton(
            text:      'Log in',
            isLoading: isLoading,
            onPressed: isLoading ? null : _handleLogin,
          ),

          const SizedBox(height: 16),

          // ─── FORGOT PASSWORD ────────────────
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: _showForgotPasswordSheet,
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: AuthColors.darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ─── OR DIVIDER ─────────────────────
          Row(children: [
            const Expanded(child: Divider(color: AuthColors.fieldBorder)),
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
            const Expanded(child: Divider(color: AuthColors.fieldBorder)),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showForgotPasswordSheet() {
    // Implementation of forgot password sheet
  }
}
