// lib/features/auth/presentation/pages/signup/step5_username_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/signup_provider.dart';
import '../../widgets/auth_components.dart';
import 'step6_save_login_screen.dart';

class Step5UsernameScreen extends ConsumerStatefulWidget {
  const Step5UsernameScreen({super.key});

  @override
  ConsumerState<Step5UsernameScreen> createState() => _Step5UsernameScreenState();
}

class _Step5UsernameScreenState extends ConsumerState<Step5UsernameScreen> {
  late TextEditingController _usernameController;
  bool _isChecking = false;
  bool? _isAvailable;

  @override
  void initState() {
    super.initState();
    // Default to a username based on full name or email if possible, 
    // but signup_provider might already have a suggested one.
    final currentUsername = ref.read(signupProvider).username;
    _usernameController = TextEditingController(text: currentUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() => _isChecking = true);
    final available = await ref.read(signupProvider.notifier).checkUsername(username);
    setState(() {
      _isChecking = false;
      _isAvailable = available;
    });

    if (available && mounted) {
      ref.read(signupProvider.notifier).updateData(username: username);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const Step6SaveLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return AuthScaffold(
      title: 'Create a username',
      subtitle: 'Add a username or use our suggestion. You can change this at any time.',
      body: [
        AuthTextField(
          controller: _usernameController,
          hintText: 'Username',
          statusIcon: _isChecking 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : _isAvailable == true 
                  ? const Icon(Icons.check_circle_outline, color: Colors.green)
                  : _isAvailable == false 
                      ? const Icon(Icons.error_outline, color: Colors.red)
                      : null,
          onChanged: (val) {
            if (_isAvailable != null) setState(() => _isAvailable = null);
          },
          onSubmitted: (_) => _onNext(),
        ),
        if (_isAvailable == false)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4),
            child: Text(
              'Username not available.',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ),
      ],
      footer: AuthPrimaryButton(
        text: 'Next',
        isLoading: _isChecking,
        onPressed: _usernameController.text.isNotEmpty ? _onNext : null,
      ),
    );
  }
}
