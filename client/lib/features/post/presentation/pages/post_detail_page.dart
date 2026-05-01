// lib/features/post/presentation/pages/post_detail_page.dart

import 'package:flutter/material.dart';
import '../../../../shared/widgets/placeholder_page.dart';

class PostDetailPage extends StatelessWidget {
  final String postId;

  const PostDetailPage({
    super.key,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Post',
      subtitle: 'Post ID: $postId',
      icon: Icons.image_outlined,
      comingDay: 'Day 13',
    );
  }
}