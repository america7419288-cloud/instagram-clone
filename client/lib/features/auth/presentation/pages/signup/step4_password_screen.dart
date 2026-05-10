// lib/features/auth/presentation/pages/signup/step4_password_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/signup_provider.dart';
import '../../widgets/auth_components.dart';
import 'step5_username_screen.dart';

class Step4PasswordScreen extends ConsumerStatefulWidget {
  const Step4PasswordScreen({super.key});

  @override
  ConsumerState<Step4PasswordScreen> createState() => _Step4PasswordScreenState();
}

class _Step4PasswordScreenState extends ConsumerState<Step4PasswordScreen> {
  final _passwordController = TextEditingController();
  bool _isObscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _onNext() {
    final password = _passwordController.text.trim();
    if (password.length < 6) return;

    ref.read(signupProvider.notifier).updateData(password: password);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const Step5UsernameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create a password',
      subtitle: 'For security, your password must be 6 characters or more.',
      body: [
        AuthTextField(
          controller: _passwordController,
          hintText: 'Password',
          isPassword: true,
          obscureText: _isObscure,
          onToggleVisibility: () => setState(() => _isObscure = !_isObscure),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _onNext(),
          textInputAction: TextInputAction.next,
        ),
      ],
      footer: AuthPrimaryButton(
        text: 'Next',
        onPressed: _passwordController.text.length >= 6 ? _onNext : null,
      ),
    );
  }
}
