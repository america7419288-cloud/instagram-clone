// lib/features/auth/presentation/pages/signup/step8_profile_pic_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/signup_provider.dart';
import '../../widgets/auth_components.dart';
import 'step9_welcome_screen.dart';

class Step8ProfilePicScreen extends ConsumerStatefulWidget {
  const Step8ProfilePicScreen({super.key});

  @override
  ConsumerState<Step8ProfilePicScreen> createState() => _Step8ProfilePicScreenState();
}

class _Step8ProfilePicScreenState extends ConsumerState<Step8ProfilePicScreen> {
  File? _image;
  final _picker = ImagePicker();
  bool _isRegistering = false;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
      ref.read(signupProvider.notifier).updateData(profileImage: _image);
    }
  }

  Future<void> _onDone() async {
    setState(() => _isRegistering = true);
    final success = await ref.read(signupProvider.notifier).register();
    setState(() => _isRegistering = false);

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Step9WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Add a profile picture',
      subtitle: 'Add a profile picture so your friends know it\'s you. Everyone will be able to see your picture.',
      body: [
        const SizedBox(height: 40),
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 1),
                image: _image != null 
                    ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover)
                    : null,
              ),
              child: _image == null 
                  ? const Icon(Icons.person, size: 80, color: Colors.grey)
                  : null,
            ),
          ),
        ),
      ],
      footer: Column(
        children: [
          AuthPrimaryButton(
            text: _image == null ? 'Add a photo' : 'Next',
            isLoading: _isRegistering,
            onPressed: _image == null ? _pickImage : _onDone,
          ),
          const SizedBox(height: 12),
          AuthSecondaryButton(
            text: 'Skip',
            onPressed: _isRegistering ? null : _onDone,
          ),
        ],
      ),
    );
  }
}
