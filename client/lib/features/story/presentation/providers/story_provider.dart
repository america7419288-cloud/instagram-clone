// lib/features/story/presentation/providers/story_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/story_model.dart';
import '../../data/repositories/story_service.dart';

// ─── STORY FEED STATE ───────────────────────────────────────
class StoryFeedState {
  final List<StoryUserGroup> userGroups;
  final bool isLoading;
  final String? errorMessage;

  const StoryFeedState({
    this.userGroups = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  StoryFeedState copyWith({
    List<StoryUserGroup>? userGroups,
    bool? isLoading,
    String? errorMessage,
  }) {
    return StoryFeedState(
      userGroups: userGroups ?? this.userGroups,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  bool get isEmpty => userGroups.isEmpty;
}

// ─── STORY FEED NOTIFIER ────────────────────────────────────
class StoryFeedNotifier extends Notifier<StoryFeedState> {
  StoryService get _storyService => ref.read(storyServiceProvider);

  @override
  StoryFeedState build() {
    Future.microtask(() => loadStories());
    return const StoryFeedState();
  }

  // ─── LOAD STORY FEED ──────────────────────────────────────
  Future<void> loadStories() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final groups = await _storyService.getStoryFeed();
      state = state.copyWith(userGroups: groups, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── MARK STORY AS VIEWED ─────────────────────────────────
  Future<void> markStoryViewed(String userId, String storyId) async {
    // Update local state immediately
    final updatedGroups = state.userGroups.map((group) {
      if (group.user.id != userId) return group;

      // Update this story to is_viewed = true
      final updatedStories = group.stories.map((story) {
        if (story.id != storyId) return story;
        return story.markAsViewed();
      }).toList();

      // Check if any unseen stories remain
      final stillHasUnseen = updatedStories.any((s) => !s.isViewed);

      return StoryUserGroup(
        user: group.user,
        stories: updatedStories,
        hasUnseen: stillHasUnseen,
        isOwn: group.isOwn,
        latestStoryAt: group.latestStoryAt,
      );
    }).toList();

    state = state.copyWith(userGroups: updatedGroups);

    // Call API (non-blocking)
    _storyService.viewStory(storyId);
  }

  // ─── ADD NEW STORY (after creating) ───────────────────────
  void addStoryToMyGroup(StoryModel newStory) {
    final groups = List<StoryUserGroup>.from(state.userGroups);

    // Find own group
    final ownIndex = groups.indexWhere((g) => g.isOwn);

    if (ownIndex != -1) {
      // Add to existing own group
      final ownGroup = groups[ownIndex];
      final updatedGroup = StoryUserGroup(
        user: ownGroup.user,
        stories: [newStory, ...ownGroup.stories],
        hasUnseen: true,
        isOwn: true,
        latestStoryAt: newStory.createdAt,
      );
      groups[ownIndex] = updatedGroup;
    }

    state = state.copyWith(userGroups: groups);
  }

  // ─── REMOVE STORY ─────────────────────────────────────────
  void removeStory(String storyId) {
    final groups = state.userGroups.map((group) {
      if (!group.isOwn) return group;

      final updatedStories = group.stories
          .where((s) => s.id != storyId)
          .toList();

      return StoryUserGroup(
        user: group.user,
        stories: updatedStories,
        hasUnseen: group.hasUnseen,
        isOwn: group.isOwn,
        latestStoryAt: group.latestStoryAt,
      );
    }).toList();

    state = state.copyWith(userGroups: groups);
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final storyServiceProvider = Provider<StoryService>((ref) {
  return StoryService();
});

final storyFeedProvider = NotifierProvider<StoryFeedNotifier, StoryFeedState>(
  StoryFeedNotifier.new,
);
