// lib/features/story/data/models/story_advanced_model.dart

// ─────────────────────────────────────────────────────
// POLL MODEL
// ─────────────────────────────────────────────────────
class StoryPollModel {
  final String id;
  final String question;
  final String optionA;
  final String optionB;
  final int votesA;
  final int votesB;
  final int totalVotes;
  final int percentA;
  final int percentB;
  final String? myVote; // 'a' | 'b' | null
  final bool hasVoted;

  // Positioning
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;

  const StoryPollModel({
    required this.id,
    required this.question,
    required this.optionA,
    required this.optionB,
    this.votesA = 0,
    this.votesB = 0,
    this.totalVotes = 0,
    this.percentA = 0,
    this.percentB = 0,
    this.myVote,
    this.hasVoted = false,
    this.x = 0.5,
    this.y = 0.5,
    this.width = 0,
    this.height = 0,
    this.rotation = 0,
  });

  factory StoryPollModel.fromJson(Map<String, dynamic> json) {
    return StoryPollModel(
      id:         json['id']?.toString() ?? '',
      question:   json['question']?.toString() ?? 'Vote',
      optionA:    json['optionA']?.toString() ?? 'Yes',
      optionB:    json['optionB']?.toString() ?? 'No',
      votesA:     int.tryParse(json['votesA']?.toString() ?? '0') ?? 0,
      votesB:     int.tryParse(json['votesB']?.toString() ?? '0') ?? 0,
      totalVotes: int.tryParse(json['totalVotes']?.toString() ?? '0') ?? 0,
      percentA:   int.tryParse(json['percentA']?.toString() ?? '0') ?? 0,
      percentB:   int.tryParse(json['percentB']?.toString() ?? '0') ?? 0,
      myVote:     json['myVote']?.toString(),
      hasVoted:   json['hasVoted'] == true,
      x:          double.tryParse(json['x']?.toString() ?? '0.5') ?? 0.5,
      y:          double.tryParse(json['y']?.toString() ?? '0.5') ?? 0.5,
      width:      double.tryParse(json['width']?.toString() ?? '0') ?? 0,
      height:     double.tryParse(json['height']?.toString() ?? '0') ?? 0,
      rotation:   double.tryParse(json['rotation']?.toString() ?? '0') ?? 0,
    );
  }

  StoryPollModel copyWith({
    String? id,
    String? question,
    String? optionA,
    String? optionB,
    int? votesA,
    int? votesB,
    int? totalVotes,
    int? percentA,
    int? percentB,
    String? myVote,
    bool? hasVoted,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
  }) {
    return StoryPollModel(
      id:         id ?? this.id,
      question:   question ?? this.question,
      optionA:    optionA ?? this.optionA,
      optionB:    optionB ?? this.optionB,
      votesA:     votesA ?? this.votesA,
      votesB:     votesB ?? this.votesB,
      totalVotes: totalVotes ?? this.totalVotes,
      percentA:   percentA ?? this.percentA,
      percentB:   percentB ?? this.percentB,
      myVote:     myVote ?? this.myVote,
      hasVoted:   hasVoted ?? this.hasVoted,
      x:          x ?? this.x,
      y:          y ?? this.y,
      width:      width ?? this.width,
      height:     height ?? this.height,
      rotation:   rotation ?? this.rotation,
    );
  }
}

// ─────────────────────────────────────────────────────
// QUESTION MODEL
// ─────────────────────────────────────────────────────
class StoryQuestionModel {
  final String id;
  final String question;
  final int answersCount;

  // Positioning
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;

  const StoryQuestionModel({
    required this.id,
    required this.question,
    this.answersCount = 0,
    this.x = 0.5,
    this.y = 0.5,
    this.width = 0,
    this.height = 0,
    this.rotation = 0,
  });

  factory StoryQuestionModel.fromJson(Map<String, dynamic> json) {
    return StoryQuestionModel(
      id:           json['id']?.toString() ?? '',
      question:     json['question']?.toString() ?? 'Ask me anything',
      answersCount: int.tryParse(
            json['answersCount']?.toString() ?? '0',
          ) ??
          0,
      x:          double.tryParse(json['x']?.toString() ?? '0.5') ?? 0.5,
      y:          double.tryParse(json['y']?.toString() ?? '0.5') ?? 0.5,
      width:      double.tryParse(json['width']?.toString() ?? '0') ?? 0,
      height:     double.tryParse(json['height']?.toString() ?? '0') ?? 0,
      rotation:   double.tryParse(json['rotation']?.toString() ?? '0') ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────
// HIGHLIGHT MODEL
// ─────────────────────────────────────────────────────
class HighlightModel {
  final String id;
  final String userId;
  final String title;
  final String? coverUrl;
  final int storiesCount;
  final List<HighlightItemModel> items;
  final DateTime createdAt;

  const HighlightModel({
    required this.id,
    required this.userId,
    required this.title,
    this.coverUrl,
    this.storiesCount = 0,
    this.items = const [],
    required this.createdAt,
  });

  factory HighlightModel.fromJson(Map<String, dynamic> json) {
    return HighlightModel(
      id:           json['id']?.toString() ?? '',
      userId:       json['userId']?.toString() ?? '',
      title:        json['title']?.toString() ?? '',
      coverUrl:     json['coverUrl']?.toString(),
      storiesCount: int.tryParse(
            json['storiesCount']?.toString() ?? '0',
          ) ??
          0,
      items: (json['items'] as List<dynamic>? ?? [])
          .map(
            (i) => HighlightItemModel.fromJson(
              i as Map<String, dynamic>,
            ),
          )
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ??
              DateTime.now()
          : DateTime.now(),
    );
  }
}

class HighlightItemModel {
  final String id;
  final String storyId;
  final String? storyUrl;
  final String? thumbnailUrl;
  final String mediaType;
  final int order;

  const HighlightItemModel({
    required this.id,
    required this.storyId,
    this.storyUrl,
    this.thumbnailUrl,
    this.mediaType = 'image',
    this.order = 0,
  });

  bool get isVideo => mediaType == 'video';

  String? get displayUrl =>
      isVideo ? (thumbnailUrl ?? storyUrl) : storyUrl;

  factory HighlightItemModel.fromJson(Map<String, dynamic> json) {
    return HighlightItemModel(
      id:           json['id']?.toString() ?? '',
      storyId:      json['storyId']?.toString() ?? '',
      storyUrl:     json['storyUrl']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      mediaType:    json['mediaType']?.toString() ?? 'image',
      order:        int.tryParse(json['order']?.toString() ?? '0') ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────
// STORY STICKER TYPE (for creator)
// ─────────────────────────────────────────────────────
enum StoryStickerType { poll, question, emoji, text }

class StoryStickerData {
  final StoryStickerType type;

  // Poll sticker
  final String? pollQuestion;
  final String? optionA;
  final String? optionB;

  // Question sticker
  final String? questionText;

  // Emoji sticker
  final String? emoji;

  // Text sticker
  final String? text;
  final double? fontSize;
  final int? colorValue;

  // Position on screen (0.0 - 1.0 normalized)
  final double dx;
  final double dy;

  const StoryStickerData({
    required this.type,
    this.pollQuestion,
    this.optionA,
    this.optionB,
    this.questionText,
    this.emoji,
    this.text,
    this.fontSize,
    this.colorValue,
    this.dx = 0.5,
    this.dy = 0.5,
  });

  StoryStickerData copyWith({
    double? dx,
    double? dy,
    String? text,
    int? colorValue,
    double? fontSize,
  }) {
    return StoryStickerData(
      type:          type,
      pollQuestion:  pollQuestion,
      optionA:       optionA,
      optionB:       optionB,
      questionText:  questionText,
      emoji:         emoji,
      text:          text ?? this.text,
      fontSize:      fontSize ?? this.fontSize,
      colorValue:    colorValue ?? this.colorValue,
      dx:            dx ?? this.dx,
      dy:            dy ?? this.dy,
    );
  }
}
