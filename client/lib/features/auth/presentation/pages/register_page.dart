// lib/features/auth/presentation/pages/register_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../data/repositories/auth_service.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  // ─── CONTROLLERS ─────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Focus nodes for keyboard navigation
  final _emailFocus = FocusNode();
  final _fullNameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // ─── STATE VARIABLES ──────────────────────────────────────
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String _usernameHelperText = '';
  Color _usernameHelperColor = AppColors.textSecondary;
  String? _serverError;

  // Auth service for username check
  final _authService = AuthService();

  // Debounce timer for username check
  // Don't check on every keystroke - wait 600ms after user stops typing
  DateTime? _lastUsernameCheck;

  @override
  void dispose() {
    // Always dispose controllers to prevent memory leaks
    _emailController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _fullNameFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ─── USERNAME AVAILABILITY CHECK ─────────────────────────
  Future<void> _checkUsernameAvailability(String username) async {
    // Don't check if too short
    if (username.length < 3) {
      setState(() {
        _isUsernameAvailable = null;
        _usernameHelperText = '';
        _isCheckingUsername = false;
      });
      return;
    }

    // Validate format before checking server
    final validPattern = RegExp(r'^[a-zA-Z0-9._]+$');
    if (!validPattern.hasMatch(username)) {
      setState(() {
        _isUsernameAvailable = false;
        _usernameHelperText = 'Only letters, numbers, dots and underscores';
        _usernameHelperColor = AppColors.secondary;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameHelperText = 'Checking availability...';
      _usernameHelperColor = AppColors.textSecondary;
    });

    // Record check time (for debounce)
    final checkTime = DateTime.now();
    _lastUsernameCheck = checkTime;

    // Wait 600ms
    await Future.delayed(const Duration(milliseconds: 600));

    // If another check started after this one, ignore this result
    if (_lastUsernameCheck != checkTime) return;

    try {
      final result = await _authService.checkUsername(username);
      final isAvailable = result['available'] as bool;

      if (mounted) {
        setState(() {
          _isUsernameAvailable = isAvailable;
          _isCheckingUsername = false;
          _usernameHelperText = isAvailable
              ? '✓ Username is available'
              : '✗ Username is already taken';
          _usernameHelperColor = isAvailable
              ? AppColors.primary
              : AppColors.secondary;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _usernameHelperText = '';
        });
      }
    }
  }

  // ─── REGISTER SUBMIT ─────────────────────────────────────
  Future<void> _handleRegister() async {
    // Clear previous server error
    setState(() => _serverError = null);

    // Validate form fields
    if (!_formKey.currentState!.validate()) return;

    // Check username availability
    if (_isUsernameAvailable == false) {
      setState(() {
        _serverError = 'Please choose a different username';
      });
      return;
    }

    // Hide keyboard
    FocusScope.of(context).unfocus();

    // Call register through Riverpod provider
    final success = await ref
        .read(authProvider.notifier)
        .register(
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          username: _usernameController.text.trim().toLowerCase(),
          password: _passwordController.text,
        );

    if (success && mounted) {
      context.go(AppRoutes.home);
    } else if (mounted) {
      // Show error from provider
      final error = ref.read(authProvider).errorMessage;
      setState(() => _serverError = error);
    }
  }

  // ─── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Watch auth state for loading
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
                const SizedBox(height: 40),

                // ─── INSTAGRAM LOGO ─────────────────────
                _buildLogo(),

                const SizedBox(height: 20),

                // ─── TAGLINE ────────────────────────────
                const Text(
                  'Sign up to see photos and videos from your friends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 24),

                // ─── EMAIL FIELD ────────────────────────
                CustomTextField(
                  hint: 'Email address',
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_fullNameFocus),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // ─── FULL NAME FIELD ─────────────────────
                CustomTextField(
                  hint: 'Full Name',
                  controller: _fullNameController,
                  focusNode: _fullNameFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_usernameFocus),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'Full name must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // ─── USERNAME FIELD ──────────────────────
                CustomTextField(
                  hint: 'Username',
                  controller: _usernameController,
                  focusNode: _usernameFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_passwordFocus),
                  helperText: _usernameHelperText.isNotEmpty
                      ? _usernameHelperText
                      : null,
                  helperColor: _usernameHelperColor,

                  // Show spinner or checkmark in suffix
                  suffixIcon: _isCheckingUsername
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CupertinoActivityIndicator(
                            radius: 8,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : _isUsernameAvailable == true
                      ? Icon(
                          PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                          color: AppColors.primary,
                          size: 20,
                        )
                      : _isUsernameAvailable == false
                      ? Icon(
                          PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                          color: AppColors.secondary,
                          size: 20,
                        )
                      : null,

                  onChanged: (value) {
                    _checkUsernameAvailability(value);
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    if (value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    if (value.length > 30) {
                      return 'Username cannot exceed 30 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(value)) {
                      return 'Only letters, numbers, dots and underscores';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // ─── PASSWORD FIELD ──────────────────────
                CustomTextField(
                  hint: 'Password',
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleRegister(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ─── SERVER ERROR ────────────────────────
                if (_serverError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.warningCircle(),
                          color: AppColors.secondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _serverError!,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ─── REGISTER BUTTON ─────────────────────
                CustomButton(
                  text: 'Sign Up',
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _handleRegister,
                ),

                const SizedBox(height: 16),

                // ─── TERMS TEXT ──────────────────────────
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    children: [
                      const TextSpan(text: 'By signing up, you agree to our '),
                      TextSpan(
                        text: 'Terms',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            // Open terms page
                          },
                      ),
                      const TextSpan(text: ', '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            // Open privacy page
                          },
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Cookies Policy',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = () {},
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ─── DIVIDER ─────────────────────────────
                const Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── ALREADY HAVE ACCOUNT ─────────────────
                const Text(
                  'Already have an account?',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),

      // ─── BOTTOM BAR - LOGIN LINK ─────────────────────────
      bottomNavigationBar: Container(
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
                  text: 'Have an account? ',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                TextSpan(
                  text: 'Log in',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      context.go(AppRoutes.login);
                    },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── LOGO WIDGET ──────────────────────────────────────────
  Widget _buildLogo() {
    return ShaderMask(
      shaderCallback: (bounds) => AppColors.instagramGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: const Text(
        'Instagram',
        style: TextStyle(
          fontSize: 40,
          fontFamily: 'Billabong', // Custom font (we'll add this)
          color: Colors.white, // ShaderMask overrides this
          letterSpacing: 1,
        ),
      ),
    );
  }
}
