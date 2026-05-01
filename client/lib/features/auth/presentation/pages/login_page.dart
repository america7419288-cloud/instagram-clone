import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Instagram',
                style: TextStyle(
                  fontSize: 48,
                  fontFamily: 'Billabong',
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Log in screen coming soon',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _goToRegister(context, ref),
                  child: const Text('Create new account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToRegister(BuildContext context, WidgetRef ref) {
    ref.read(authProvider.notifier).clearError();
    context.push(AppRoutes.register);
  }
}
