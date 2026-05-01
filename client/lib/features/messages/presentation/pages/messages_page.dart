// lib/features/messages/presentation/pages/messages_page.dart

import 'package:flutter/material.dart';
import '../../../../shared/widgets/placeholder_page.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Messages',
      subtitle: 'Direct messages with your friends',
      icon: Icons.send_outlined,
      comingDay: 'Day 22',
    );
  }
}