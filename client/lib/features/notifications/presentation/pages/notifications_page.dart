// lib/features/notifications/presentation/pages/notifications_page.dart

import 'package:flutter/material.dart';
import '../../../../shared/widgets/placeholder_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Activity',
      subtitle: 'Likes, comments and follows will appear here',
      icon: Icons.favorite_border,
      comingDay: 'Day 18',
    );
  }
}