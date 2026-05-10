// lib/features/auth/presentation/pages/signup/step6_save_login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/auth_components.dart';
import 'step7_terms_screen.dart';

class Step6SaveLoginScreen extends ConsumerWidget {
  const Step6SaveLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthScaffold(
      title: 'Save login info?',
      subtitle: "We'll save the login info for your new account, so you won't need to enter it when you log in again.",
      body: const [], // Subtitle is enough here for Instagram's clean look
      footer: Column(
        children: [
          AuthPrimaryButton(
            text: 'Save',
            onPressed: () {
              // Optionally handle saving locally here, but for now just proceed
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const Step7TermsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          AuthSecondaryButton(
            text: 'Not now',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const Step7TermsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
