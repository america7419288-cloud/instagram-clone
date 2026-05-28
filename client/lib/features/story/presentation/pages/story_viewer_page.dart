// lib/features/story/presentation/pages/story_viewer_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/story_provider.dart';
import '../../../../features/stories/pages/story_viewer_shell.dart';
import '../../../../features/stories/models/story_model.dart' as ns;

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

    // Convert old story models to new redesigned story models
    final newUsers = groups.map((g) {
      return ns.StoryUserModel(
        id: g.user.id,
        username: g.user.username,
        avatarUrl: g.user.profilePicUrl ?? '',
        isVerified: g.user.isVerified,
        stories: g.stories.map((s) {
          ns.StoryMediaType mediaType = ns.StoryMediaType.image;
          if (s.isVideo) {
            mediaType = ns.StoryMediaType.video;
          }

          ns.StoryPollData? pollData;
          if (s.poll != null) {
            int? myVoteVal;
            if (s.poll!.myVote == 'a') {
              myVoteVal = 1;
            } else if (s.poll!.myVote == 'b') {
              myVoteVal = 2;
            }
            pollData = ns.StoryPollData(
              question: s.poll!.question,
              option1: s.poll!.optionA,
              option2: s.poll!.optionB,
              votes1: s.poll!.votesA,
              votes2: s.poll!.votesB,
              myVote: myVoteVal,
            );
          }

          ns.StoryQuestionData? questionData;
          if (s.question != null) {
            questionData = ns.StoryQuestionData(
              prompt: s.question!.question,
            );
          }

          ns.StoryLinkData? linkData;
          if (s.link != null && s.link!.isNotEmpty) {
            linkData = ns.StoryLinkData(
              url: s.link!,
              displayText: 'Learn More',
            );
          }

          ns.StoryMusicData? musicData;
          if (s.music != null) {
            musicData = ns.StoryMusicData(
              songName: s.music!.title,
              artistName: s.music!.artist,
              albumArtUrl: s.music!.thumbnail ?? '',
              previewUrl: '',
              startSeconds: s.music!.startTime.toDouble(),
            );
          }

          return ns.StoryModel(
            id: s.id,
            mediaUrl: s.mediaUrl,
            mediaType: mediaType,
            duration: Duration(milliseconds: ((s.duration ?? 5.0) * 1000).toInt()),
            user: ns.StoryUserModel(
              id: g.user.id,
              username: g.user.username,
              avatarUrl: g.user.profilePicUrl ?? '',
              isVerified: g.user.isVerified,
              stories: const [],
            ),
            poll: pollData,
            question: questionData,
            link: linkData,
            music: musicData,
            createdAt: s.createdAt ?? DateTime.now(),
            isViewedByMe: s.isViewed,
            viewCount: s.viewCount,
          );
        }).toList(),
        hasUnseenStories: g.hasUnseen,
      );
    }).toList();

    return StoryViewerShell(
      users: newUsers,
      initialUserIndex: initialIndex,
      currentUserId: userId,
    );
  }
}
