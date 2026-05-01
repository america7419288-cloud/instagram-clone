// lib/features/profile/presentation/pages/profile_page.dart

import 'package:flutter/material.dart';
import '../../../../shared/widgets/placeholder_page.dart';

class ProfilePage extends StatelessWidget {
  final String? username;

  const ProfilePage({
    super.key,
    this.username,
  });

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: username != null ? '@$username' : 'Profile',
      subtitle: 'User profile page',
      icon: Icons.person_outline,
      comingDay: 'Day 21',
    );
  }
}