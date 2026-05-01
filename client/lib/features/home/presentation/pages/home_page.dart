// lib/features/home/presentation/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(child: HomePageContent()),
    );
  }
}

class HomePageContent extends ConsumerWidget {
  const HomePageContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeHeader(),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(user),
                    const SizedBox(height: 16),
                    _buildPlaceholderFeed(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(UserModel? user) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.instagramGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Day 7 Complete! GoRouter',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (user != null) ...[
            _infoRow(Icons.person_outline, '@${user.username}'),
            _infoRow(Icons.email_outlined, user.email),
            _infoRow(
              Icons.lock_outline,
              user.isPrivate ? 'Private' : 'Public Account',
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'GoRouter active\n'
              'Auth guard working\n'
              'Bottom nav with ShellRoute\n'
              'Real feed coming soon',
              style: TextStyle(color: Colors.white, fontSize: 12, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderFeed(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => _buildPlaceholderPost(context, index),
      ),
    );
  }

  Widget _buildPlaceholderPost(BuildContext context, int index) {
    final colors = [
      const Color(0xFF833AB4),
      const Color(0xFFFD1D1D),
      const Color(0xFF405DE6),
    ];
    final color = colors[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/profile/user_$index'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, size: 20, color: color),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => context.push('/profile/user_$index'),
                child: Text(
                  'user_$index',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.more_horiz),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/post/post_id_$index'),
          child: Container(
            width: double.infinity,
            height: 300,
            color: color.withValues(alpha: 0.1),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 60,
                    color: color.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to open post detail',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.favorite_border, size: 26),
              SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline, size: 24),
              SizedBox(width: 16),
              Icon(Icons.send_outlined, size: 24),
              Spacer(),
              Icon(Icons.bookmark_border, size: 24),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.instagramGradient.createShader(
                    Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                  ),
              child: const Text(
                'Instagram',
                style: TextStyle(
                  fontSize: 28,
                  fontFamily: 'Billabong',
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => context.go(AppRoutes.notifications),
              icon: const Icon(
                Icons.favorite_border,
                color: AppColors.textPrimary,
              ),
            ),
            IconButton(
              onPressed: () => context.go(AppRoutes.messages),
              icon: const Icon(
                Icons.send_outlined,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
