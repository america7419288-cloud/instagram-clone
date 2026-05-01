// lib/features/post/presentation/pages/create_post_page.dart

import 'package:flutter/material.dart';
import '../../../../shared/widgets/placeholder_page.dart';

class CreatePostPage extends StatelessWidget {
  const CreatePostPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Create Post',
      subtitle: 'Share photos and videos with your followers',
      icon: Icons.add_box_outlined,
      comingDay: 'Day 14',
    );
  }
}