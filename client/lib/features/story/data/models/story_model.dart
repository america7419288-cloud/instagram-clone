import 'story_advanced_model.dart';

// ─── SINGLE STORY ──────────────────────────────────────────
class StoryModel {
  final String id;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String mediaType; // 'image' or 'video'
  final String? caption;
  final String? link;
  final String audience;
  final int? width;
  final int? height;
  final double? duration; // video duration
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final bool isViewed;
  final bool isOwnStory;
  final int viewCount;
  final StoryUserModel? user;

  // Interactive features
  final StoryPollModel? poll;
  final StoryQuestionModel? question;
  final StoryMusicModel? music;

  const StoryModel({
    required this.id,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.mediaType,
    this.caption,
    this.link,
    required this.audience,
    this.width,
    this.height,
    this.duration,
    this.expiresAt,
    this.createdAt,
    required this.isViewed,
    required this.isOwnStory,
    required this.viewCount,
    this.user,
    this.poll,
    this.question,
    this.music,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id']?.toString() ?? '',
      mediaUrl: json['media_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      mediaType: json['media_type'] ?? 'image',
      caption: json['caption'],
      link: json['link'],
      audience: json['audience'] ?? 'followers',
      width: json['width'],
      height: json['height'],
      duration: json['duration']?.toDouble(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      isViewed: json['is_viewed'] ?? false,
      isOwnStory: json['is_own_story'] ?? false,
      viewCount: json['view_count'] ?? 0,
      user: json['user'] != null
          ? StoryUserModel.fromJson(json['user'])
          : null,
      poll: json['poll'] != null ? StoryPollModel.fromJson(json['poll']) : null,
      question: json['question'] != null
          ? StoryQuestionModel.fromJson(json['question'])
          : null,
      music: json['music'] != null
          ? StoryMusicModel.fromJson(json['music'])
          : null,
    );
  }

  // Create copy with isViewed set to true
  StoryModel markAsViewed() {
    return StoryModel(
      id: id,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      mediaType: mediaType,
      caption: caption,
      link: link,
      audience: audience,
      width: width,
      height: height,
      duration: duration,
      expiresAt: expiresAt,
      createdAt: createdAt,
      isViewed: true,  // ← Updated
      isOwnStory: isOwnStory,
      viewCount: viewCount,
      user: user,
      poll: poll,
      question: question,
      music: music,
    );
  }

  bool get isVideo => mediaType == 'video';
  bool get isImage => mediaType == 'image';
}

// ─── STORY MUSIC ───────────────────────────────────────────
class StoryMusicModel {
  final String id;
  final String title;
  final String artist;
  final String? thumbnail;
  final int startTime;
  final int duration;

  const StoryMusicModel({
    required this.id,
    required this.title,
    required this.artist,
    this.thumbnail,
    required this.startTime,
    required this.duration,
  });

  factory StoryMusicModel.fromJson(Map<String, dynamic> json) {
    return StoryMusicModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      thumbnail: json['thumbnail'],
      startTime: json['start_time'] ?? 0,
      duration: json['duration'] ?? 15,
    );
  }
}

// ─── STORY USER ────────────────────────────────────────────
class StoryUserModel {
  final String id;
  final String username;
  final String? fullName;
  final String? profilePicUrl;
  final bool isVerified;
  final bool isFollowing;

  const StoryUserModel({
    required this.id,
    required this.username,
    this.fullName,
    this.profilePicUrl,
    required this.isVerified,
    this.isFollowing = false,
  });

  factory StoryUserModel.fromJson(Map<String, dynamic> json) {
    return StoryUserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      fullName: json['full_name'],
      profilePicUrl: json['profile_pic_url'],
      isVerified: json['is_verified'] ?? false,
      isFollowing: json['is_following'] ?? false,
    );
  }
}

// ─── STORY USER GROUP ──────────────────────────────────────
// Groups one user's stories together
// This is what the StoriesBar shows
class StoryFeedModel {
  final StoryUserModel user;
  final List<StoryModel> stories;
  final bool hasUnseen;    // Does this user have unseen stories?
  final bool isOwn;        // Is this the current user's stories?
  final DateTime? latestStoryAt;

  const StoryFeedModel({
    required this.user,
    required this.stories,
    required this.hasUnseen,
    required this.isOwn,
    this.latestStoryAt,
  });

  factory StoryFeedModel.fromJson(Map<String, dynamic> json) {
    final user = StoryUserModel.fromJson(json['user'] ?? {});
    final storiesJson = json['stories'] as List<dynamic>? ?? [];
    final stories = storiesJson
        .map((s) => StoryModel.fromJson(s as Map<String, dynamic>))
        .toList();

    return StoryFeedModel(
      user: user,
      stories: stories,
      hasUnseen: json['has_unseen'] ?? false,
      isOwn: json['is_own'] ?? false,
      latestStoryAt: json['latest_story_at'] != null
          ? DateTime.tryParse(json['latest_story_at'])
          : null,
    );
  }

  // Total story count for this user
  int get storyCount => stories.length;

  // Index of first unseen story (or 0 if all seen)
  int get firstUnseenIndex {
    final index = stories.indexWhere((s) => !s.isViewed);
    return index == -1 ? 0 : index;
  }
}
