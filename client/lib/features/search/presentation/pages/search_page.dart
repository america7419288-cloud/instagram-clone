// lib/features/search/presentation/pages/search_page.dart

import 'package:flutter/material.dart';
import '../../../../shared/widgets/placeholder_page.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Search & Explore',
      subtitle: 'Discover photos, videos and people',
      icon: Icons.search,
      comingDay: 'Day 20',
    );
  }
}