// lib/features/story/presentation/pages/story_viewer_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/story_viewer.dart';
import '../providers/story_provider.dart';

class StoryViewerPage extends ConsumerWidget {
  final String userId;

  const StoryViewerPage({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyState = ref.watch(storyFeedProvider);
    
    if (storyState.isLoading && storyState.userGroups.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final groups = storyState.userGroups;
    final initialIndex = groups.indexWhere((g) => g.user.id == userId);

    if (initialIndex == -1) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Story not found',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return StoryViewer(
      groups: groups,
      initialGroupIndex: initialIndex,
    );
  }
}
