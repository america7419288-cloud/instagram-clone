// lib/features/story/presentation/pages/story_viewer_page.dart

import 'package:flutter/material.dart';
import '../../../../shared/widgets/placeholder_page.dart';

class StoryViewerPage extends StatelessWidget {
  final String userId;

  const StoryViewerPage({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Story',
      subtitle: 'Story viewer for user: $userId',
      icon: Icons.circle_outlined,
      comingDay: 'Day 16',
    );
  }
}