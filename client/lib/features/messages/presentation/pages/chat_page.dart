// lib/features/messages/presentation/pages/chat_page.dart

import 'package:flutter/material.dart';
import '../../../../shared/widgets/placeholder_page.dart';

class ChatPage extends StatelessWidget {
  final String conversationId;

  const ChatPage({
    super.key,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Chat',
      subtitle: 'Conversation: $conversationId',
      icon: Icons.chat_bubble_outline,
      comingDay: 'Day 22',
    );
  }
}