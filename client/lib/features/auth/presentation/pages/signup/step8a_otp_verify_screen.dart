import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/signup_provider.dart';
import '../../widgets/auth_components.dart';
import 'step9_welcome_screen.dart';
import '../../../../../shared/widgets/app_snackbar.dart';

class Step8aOtpVerifyScreen extends ConsumerStatefulWidget {
  const Step8aOtpVerifyScreen({super.key});

  @override
  ConsumerState<Step8aOtpVerifyScreen> createState() => _Step8aOtpVerifyScreenState();
}

class _Step8aOtpVerifyScreenState extends ConsumerState<Step8aOtpVerifyScreen> {
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  bool _isVerifying = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  Future<void> _onVerify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) return;

    setState(() => _isVerifying = true);
    final success = await ref.read(signupProvider.notifier).verifyOtp(otp);
    setState(() => _isVerifying = false);

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Step9WelcomeScreen()),
        (route) => false,
      );
    } else if (mounted) {
      final error = ref.read(signupProvider).error;
      AppSnackbar.error(context, error ?? 'Verification failed. Please check your code.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(signupProvider).email;
    final isOtpValid = _otpCtrl.text.trim().length == 6;

    return AuthScaffold(
      title: 'Enter confirmation code',
      subtitle: 'Enter the 6-digit confirmation code we sent to $email.',
      body: [
        const SizedBox(height: 20),
        AuthTextField(
          controller: _otpCtrl,
          hintText: 'Confirmation code',
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => isOtpValid ? _onVerify() : null,
        ),
      ],
      footer: AuthPrimaryButton(
        text: 'Verify',
        isLoading: _isVerifying,
        onPressed: isOtpValid ? _onVerify : null,
      ),
    );
  }
}
