// lib/features/auth/presentation/pages/signup/step1_email_phone_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/signup_provider.dart';
import '../../widgets/auth_components.dart';
import 'step2_fullname_screen.dart';

class Step1EmailPhoneScreen extends ConsumerStatefulWidget {
  const Step1EmailPhoneScreen({super.key});

  @override
  ConsumerState<Step1EmailPhoneScreen> createState() => _Step1EmailPhoneScreenState();
}

class _Step1EmailPhoneScreenState extends ConsumerState<Step1EmailPhoneScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    final isEmailTab = _tabController.index == 0;
    final value = isEmailTab ? _emailController.text.trim() : _phoneController.text.trim();
    
    if (value.isEmpty) return;

    if (isEmailTab) {
      setState(() => _isChecking = true);
      final available = await ref.read(signupProvider.notifier).checkEmail(value);
      setState(() => _isChecking = false);
      
      if (available && mounted) {
        ref.read(signupProvider.notifier).updateData(email: value);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const Step2FullNameScreen()),
        );
      }
    } else {
      // Phone support placeholder
      ref.read(signupProvider.notifier).updateData(phone: value);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const Step2FullNameScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'What\'s your email?',
      subtitle: 'Enter the email where you can be reached. No one will see this on your profile.',
      body: [
        TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          labelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Email'),
            Tab(text: 'Mobile number'),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 100,
          child: TabBarView(
            controller: _tabController,
            children: [
              AuthTextField(
                controller: _emailController,
                hintText: 'Email',
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _onNext(),
              ),
              AuthTextField(
                controller: _phoneController,
                hintText: 'Mobile number',
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _onNext(),
              ),
            ],
          ),
        ),
      ],
      footer: AuthPrimaryButton(
        text: 'Next',
        isLoading: _isChecking,
        onPressed: (_tabController.index == 0 ? _emailController.text.isNotEmpty : _phoneController.text.isNotEmpty) 
            ? _onNext : null,
      ),
    );
  }
}
