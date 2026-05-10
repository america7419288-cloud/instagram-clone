// lib/features/auth/presentation/pages/signup/step7_terms_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/auth_components.dart';
import 'step8_profile_pic_screen.dart';

class Step7TermsScreen extends ConsumerStatefulWidget {
  const Step7TermsScreen({super.key});

  @override
  ConsumerState<Step7TermsScreen> createState() => _Step7TermsScreenState();
}

class _Step7TermsScreenState extends ConsumerState<Step7TermsScreen> {
  bool _isLoading = false;

  Future<void> _onAgree() async {
    // In a real app, this might trigger the actual registration call if there are no more steps,
    // but Instagram has a profile pic step after this.
    // However, some versions of the flow register the user HERE.
    // Let's assume we proceed to profile pic first.
    
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const Step8ProfilePicScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: "Agree to Instagram's\nTerms and Policies",
      subtitle: "By tapping I agree, you agree to create an account and to Instagram's Terms, Privacy Policy and Cookies Policy.",
      body: [
        const SizedBox(height: 20),
        const Text(
          "The Privacy Policy describes the ways we can use the information we collect when you create an account. For example, we use this information to provide, personalize and improve our products, including ads.",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
      footer: AuthPrimaryButton(
        text: 'I agree',
        isLoading: _isLoading,
        onPressed: _onAgree,
      ),
    );
  }
}
