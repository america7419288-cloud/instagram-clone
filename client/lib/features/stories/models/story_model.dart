import 'package:flutter/material.dart';

enum StoryMediaType { image, video, text, boomerang }
enum StoryMusicPosition { top, bottom }

class StoryModel {
  final String id;
  final String mediaUrl;
  final StoryMediaType mediaType;
  final Duration duration;
  final StoryUserModel user;
  final List<StoryTextOverlay> textOverlays;
  final StoryMusicData? music;
  final StoryPollData? poll;
  final StoryQuestionData? question;
  final StoryLinkData? link;
  final Color? backgroundColor;
  final List<Color>? gradientColors;
  final String? backgroundPattern;
  final DateTime createdAt;
  final bool isViewedByMe;
  final int viewCount;
  final bool isCloseFriend;

  const StoryModel({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    this.duration = const Duration(seconds: 7),
    required this.user,
    this.textOverlays = const [],
    this.music,
    this.poll,
    this.question,
    this.link,
    this.backgroundColor,
    this.gradientColors,
    this.backgroundPattern,
    required this.createdAt,
    this.isViewedByMe = false,
    this.viewCount = 0,
    this.isCloseFriend = false,
  });
}

class StoryUserModel {
  final String id;
  final String username;
  final String avatarUrl;
  final bool isVerified;
  final bool isCloseFriend;
  final List<StoryModel> stories;
  final bool hasUnseenStories;

  const StoryUserModel({
    required this.id,
    required this.username,
    required this.avatarUrl,
    this.isVerified = false,
    this.isCloseFriend = false,
    required this.stories,
    this.hasUnseenStories = true,
  });
}

class StoryTextOverlay {
  final String text;
  final Color color;
  final Color backgroundColor;
  final double fontSize;
  final Offset position;
  final double scale;
  final double rotation;
  final TextStyle style;

  const StoryTextOverlay({
    required this.text,
    required this.color,
    this.backgroundColor = Colors.transparent,
    this.fontSize = 28.0,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    required this.style,
  });
}

class StoryMusicData {
  final String songName;
  final String artistName;
  final String albumArtUrl;
  final String previewUrl;
  final StoryMusicPosition position;
  final double startSeconds;

  const StoryMusicData({
    required this.songName,
    required this.artistName,
    required this.albumArtUrl,
    required this.previewUrl,
    this.position = StoryMusicPosition.bottom,
    this.startSeconds = 0,
  });
}

class StoryPollData {
  final String question;
  final String option1;
  final String option2;
  final int votes1;
  final int votes2;
  final int? myVote; // null = not voted

  const StoryPollData({
    required this.question,
    required this.option1,
    required this.option2,
    this.votes1 = 0,
    this.votes2 = 0,
    this.myVote,
  });

  int get totalVotes => votes1 + votes2;
  double get percent1 => totalVotes == 0 ? 0.5 : votes1 / totalVotes;
  double get percent2 => totalVotes == 0 ? 0.5 : votes2 / totalVotes;
}

class StoryQuestionData {
  final String prompt;
  final String? myAnswer;
  final List<String> responses;

  const StoryQuestionData({
    required this.prompt,
    this.myAnswer,
    this.responses = const [],
  });
}

class StoryLinkData {
  final String url;
  final String displayText;
  final String? thumbnailUrl;

  const StoryLinkData({
    required this.url,
    required this.displayText,
    this.thumbnailUrl,
  });
}
