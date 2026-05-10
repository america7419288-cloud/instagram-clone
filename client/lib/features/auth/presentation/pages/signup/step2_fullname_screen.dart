// lib/features/auth/presentation/pages/signup/step2_fullname_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/signup_provider.dart';
import '../../widgets/auth_components.dart';
import 'step3_birthday_screen.dart';

class Step2FullNameScreen extends ConsumerStatefulWidget {
  const Step2FullNameScreen({super.key});

  @override
  ConsumerState<Step2FullNameScreen> createState() =>
      _Step2FullNameScreenState();
}

class _Step2FullNameScreenState extends ConsumerState<Step2FullNameScreen> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    // Restore if user came back
    _ctrl.text = ref.read(signupProvider).fullName;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canNext => _ctrl.text.trim().length >= 2;

  void _next() {
    final name = _ctrl.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Please enter your full name');
      return;
    }
    FocusScope.of(context).unfocus();
    ref.read(signupProvider.notifier).setFullName(name);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const Step3BirthdayScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      footer: AuthPrimaryButton(
        text: 'Next',
        isDisabled: !_canNext,
        onPressed: _canNext ? _next : null,
      ),
      title: "What's your name?",
      subtitle: 'Add your name so friends can find you.\nYou can always change it later.',
      body: [
        AuthTextField(
          placeholder:     'Full name',
          controller:      _ctrl,
          focusNode:       _focus,
          keyboardType:    TextInputType.name,
          textInputAction: TextInputAction.next,
          errorText:       _error,
          onChanged: (v) => setState(() => _error = null),
          onClear:   () => setState(() {}),
        ),

        const SizedBox(height: 16),

        Row(children: const [
          Icon(Icons.info_outline, size: 14, color: AuthColors.greyText),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'People who use our service use their real names.\n'
              'Add the name you go by, even if it has '
              'special characters.',
              style: TextStyle(
                color: AuthColors.greyText,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ]),
      ],
    );
  }
}
