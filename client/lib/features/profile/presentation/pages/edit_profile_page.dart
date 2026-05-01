// lib/features/profile/presentation/pages/edit_profile_page.dart

import 'package:flutter/material.dart';
import '../../../../shared/widgets/placeholder_page.dart';

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Edit Profile',
      subtitle: 'Update your name, bio, and profile picture',
      icon: Icons.edit_outlined,
      comingDay: 'Day 21',
    );
  }
}