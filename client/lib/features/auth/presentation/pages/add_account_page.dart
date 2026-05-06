// lib/features/auth/presentation/pages/add_account_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/auth_provider.dart';

class AddAccountPage extends ConsumerStatefulWidget {
  const AddAccountPage({super.key});

  @override
  ConsumerState<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends ConsumerState<AddAccountPage> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading       = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      await ref.read(authProvider.notifier).login(
            identifier: _emailCtrl.text.trim(),
            password:   _passwordCtrl.text,
          );

      if (mounted) {
        HapticFeedback.mediumImpact();
        AppSnackbar.success(context, 'Account added & switched!');
        // Pop back to wherever we came from
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Add Account'),
        leading: IconButton(
          icon: Icon(PhosphorIcons.x()),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Logo ───────────────────────────────
                Center(
                  child: Text(
                    'Instagram',
                    style: TextStyle(
                      fontFamily: 'Billabong',
                      fontSize:   42,
                      color:      isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Log into another account',
                    style: TextStyle(
                      fontSize: 14,
                      color:    isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // ─── Email ──────────────────────────────
                Text(
                  'Email or Username',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w500,
                    color:      isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller:    _emailCtrl,
                  keyboardType:  TextInputType.emailAddress,
                  autocorrect:   false,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:  'Email or username',
                    fillColor: isDark
                        ? AppColors.darkInputBackground
                        : AppColors.inputBackground,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your email or username';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ─── Password ───────────────────────────
                Text(
                  'Password',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w500,
                    color:      isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller:   _passwordCtrl,
                  obscureText:  _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:  'Password',
                    fillColor: isDark
                        ? AppColors.darkInputBackground
                        : AppColors.inputBackground,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? PhosphorIcons.eyeClosed()
                            : PhosphorIcons.eye(),
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // ─── Login button ────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding:         const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.6),
                    ),
                    child: _isLoading
                        ? const CupertinoActivityIndicator(
                            radius: 10,
                            color: Colors.white,
                          )
                        : const Text(
                            'Log in',
                            style: TextStyle(
                              fontSize:   16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Register link ───────────────────────
                Center(
                  child: TextButton(
                    onPressed: () {
                      context.pop();
                      context.push('/register');
                    },
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color:    isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                        children: const [
                          TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text:  'Sign up',
                            style: TextStyle(
                              color:      AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
