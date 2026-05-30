// lib/features/auth/presentation/pages/signup/step3_birthday_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/signup_provider.dart';
import '../../widgets/auth_components.dart';
import 'step4_password_screen.dart';

class Step3BirthdayScreen extends ConsumerStatefulWidget {
  const Step3BirthdayScreen({super.key});

  @override
  ConsumerState<Step3BirthdayScreen> createState() =>
      _Step3BirthdayScreenState();
}

class _Step3BirthdayScreenState extends ConsumerState<Step3BirthdayScreen> {
  late DateTime _selected;
  final DateTime _maxDate = DateTime.now().subtract(const Duration(days: 13 * 365));
  final DateTime _minDate = DateTime(1905, 1, 1);
  String? _ageError;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(signupProvider).birthday ??
        DateTime.now().subtract(const Duration(days: 6940)); // ~19 years
  }

  bool get _isOver13 {
    final cutoff = DateTime.now().subtract(const Duration(days: 13 * 365));
    return _selected.isBefore(cutoff);
  }

  void _next() {
    if (!_isOver13) {
      setState(() => _ageError = 'You must be at least 13 years old to sign up.');
      return;
    }
    ref.read(signupProvider.notifier).setBirthday(_selected);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const Step4PasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('MMMM d, yyyy').format(_selected);

    return AuthScaffold(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_ageError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _ageError!,
                style: const TextStyle(
                  color: AuthColors.errorRed, fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          AuthPrimaryButton(
            text: 'Next',
            onPressed: _next,
          ),
        ],
      ),
      title: "What's your birthday?",
      subtitle:
          'Use your own birthday, even if this account is for a '
          'business, a pet, or something else. No one will see this '
          'on your profile.',
      body: [
        // ─── Formatted Date Display ───────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(AuthDimens.fieldRadius),
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : AuthColors.fieldBorder),
          ),
          child: Text(
            formatted,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AuthColors.darkText,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ─── Date Picker ─────────────────────────
        SizedBox(
          height: 200,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _selected,
            minimumDate: _minDate,
            maximumDate: DateTime.now(),
            onDateTimeChanged: (dt) {
              setState(() {
                _selected  = dt;
                _ageError  = null;
              });
            },
          ),
        ),

        const SizedBox(height: 12),

        // Age note
        Row(children: const [
          Icon(Icons.lock_outline, size: 14, color: AuthColors.greyText),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'You won\'t be able to change your birthday after you '
              'complete registration.',
              style: TextStyle(
                color: AuthColors.greyText, fontSize: 12, height: 1.4,
              ),
            ),
          ),
        ]),
      ],
    );
  }
}
