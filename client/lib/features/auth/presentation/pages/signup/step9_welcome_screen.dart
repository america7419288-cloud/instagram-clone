// lib/features/auth/presentation/pages/signup/step9_welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/signup_provider.dart';
import '../../widgets/auth_components.dart';
import '../../../signup/presentation/follow_suggestions_screen.dart';

class Step9WelcomeScreen extends ConsumerWidget {
  const Step9WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(signupProvider).username;

    return AuthScaffold(
      showBack: false,
      showLogo: false, // Custom welcome icon instead
      title: 'Welcome to Instagram,\n$username',
      subtitle: 'Your account has been created. You can now start sharing and connecting with friends.',
      body: [
        const SizedBox(height: 40),
        const Center(
          child: Icon(Icons.check_circle_outline, size: 100, color: Colors.green),
        ),
      ],
      footer: AuthPrimaryButton(
        text: 'Complete registration',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FollowSuggestionsScreen(
                onComplete: () => context.go('/'),
              ),
            ),
          );
        },
      ),
    );
  }
}
