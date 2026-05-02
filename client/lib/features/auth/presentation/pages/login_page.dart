// lib/features/auth/presentation/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/navigation_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // ─── CONTROLLERS ──────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  final _identifierFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // ─── STATE ────────────────────────────────────────────────
  String? _serverError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ─── HANDLE LOGIN ─────────────────────────────────────────
  Future<void> _handleLogin() async {
    // Clear previous error
    setState(() => _serverError = null);

    // Validate form
    if (!_formKey.currentState!.validate()) return;

    // Hide keyboard
    FocusScope.of(context).unfocus();

    // Call login through Riverpod
    final success = await ref
        .read(authProvider.notifier)
        .login(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );

    if (success && mounted) {
      context.go(AppRoutes.home);
    } else if (mounted) {
      // Show error
      final error = ref.read(authProvider).errorMessage;
      setState(() => _serverError = error);
    }
  }

  // ─── NAVIGATE TO REGISTER ─────────────────────────────────
  void _goToRegister() {
    // Clear error when navigating
    ref.read(authProvider.notifier).clearError();

    context.pushIfNotCurrent(AppRoutes.register);
  }

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // ─── LOGO ──────────────────────────────
                _buildLogo(),

                const SizedBox(height: 36),

                // ─── IDENTIFIER FIELD ──────────────────
                CustomTextField(
                  hint: 'Phone number, username or email',
                  controller: _identifierController,
                  focusNode: _identifierFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_passwordFocus),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your username or email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // ─── PASSWORD FIELD ────────────────────
                CustomTextField(
                  hint: 'Password',
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ─── SERVER ERROR ──────────────────────
                if (_serverError != null) _buildErrorBox(_serverError!),

                // ─── FORGOT PASSWORD ───────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _showForgotPasswordSheet();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: AppColors.textLink,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ─── LOGIN BUTTON ──────────────────────
                CustomButton(
                  text: 'Log In',
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _handleLogin,
                ),

                const SizedBox(height: 24),

                // ─── OR DIVIDER ────────────────────────
                _buildOrDivider(),

                const SizedBox(height: 24),

                // ─── FACEBOOK LOGIN (UI only for now) ──
                _buildFacebookButton(),

                const SizedBox(height: 24),

                // ─── GET THE APP ───────────────────────
                _buildGetTheApp(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),

      // ─── BOTTOM - SIGN UP LINK ─────────────────────────
      bottomNavigationBar: _buildBottomSignUp(),
    );
  }

  // ─── HELPER WIDGETS ───────────────────────────────────────

  Widget _buildLogo() {
    return ShaderMask(
      shaderCallback: (bounds) => AppColors.instagramGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: const Text(
        'Instagram',
        style: TextStyle(
          fontSize: 50,
          fontFamily: 'Billabong',
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildErrorBox(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.secondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }

  Widget _buildFacebookButton() {
    return GestureDetector(
      onTap: () {
        AppSnackbar.info(context, 'Facebook login coming soon!');
      },
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Facebook icon (using text for now)
          Icon(
            Icons.facebook,
            color: Color(0xFF1877F2), // Facebook blue
            size: 22,
          ),
          SizedBox(width: 8),
          Text(
            'Continue with Facebook',
            style: TextStyle(
              color: Color(0xFF1877F2),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGetTheApp() {
    return Column(
      children: [
        const Text(
          'Get the app.',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        // App store badges
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStoreBadge('App Store', Icons.apple),
            const SizedBox(width: 8),
            _buildStoreBadge('Google Play', Icons.android),
          ],
        ),
      ],
    );
  }

  Widget _buildStoreBadge(String store, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text(
            store,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSignUp() {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Center(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14),
            children: [
              const TextSpan(
                text: "Don't have an account? ",
                style: TextStyle(color: AppColors.textSecondary),
              ),
              TextSpan(
                text: 'Sign up',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                recognizer: TapGestureRecognizer()..onTap = _goToRegister,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FORGOT PASSWORD BOTTOM SHEET ─────────────────────────
  void _showForgotPasswordSheet() {
    final emailController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            // Move up when keyboard appears
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Lock icon
              const Center(
                child: Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Center(
                child: Text(
                  'Trouble logging in?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Description
              const Center(
                child: Text(
                  "Enter your email and we'll send you a link to get back into your account.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Email input
              CustomTextField(
                hint: 'Email address',
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),

              // Send button
              CustomButton(
                text: 'Send Login Link',
                onPressed: () {
                  // Will implement forgot password API later
                  Navigator.pop(context);
                  AppSnackbar.success(
                    this.context,
                    'Password reset link sent! Check your email.',
                  );
                },
              ),
              const SizedBox(height: 12),

              // OR divider
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),

              // Create new account
              CustomButton(
                text: 'Create New Account',
                isOutlined: true,
                onPressed: () {
                  Navigator.pop(context);
                  _goToRegister();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
