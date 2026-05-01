// lib/features/post/data/models/post_model.dart

// ─── POST MEDIA MODEL ──────────────────────────────────────
class PostMediaModel {
  final String id;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String? smallUrl;
  final String? mediumUrl;
  final String mediaType; // 'image' or 'video'
  final int displayOrder;
  final int? width;
  final int? height;
  final double? duration;

  const PostMediaModel({
    required this.id,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.smallUrl,
    this.mediumUrl,
    required this.mediaType,
    required this.displayOrder,
    this.width,
    this.height,
    this.duration,
  });

  factory PostMediaModel.fromJson(Map<String, dynamic> json) {
    return PostMediaModel(
      id: json['id'] ?? '',
      mediaUrl: json['media_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      smallUrl: json['small_url'],
      mediumUrl: json['medium_url'],
      mediaType: json['media_type'] ?? 'image',
      displayOrder: _asInt(json['display_order']),
      width: json['width'] == null ? null : _asInt(json['width']),
      height: json['height'] == null ? null : _asInt(json['height']),
      duration: _asDouble(json['duration']),
    );
  }

  // Best URL for feed display (medium → original)
  String get feedUrl => mediumUrl ?? mediaUrl;

  // Best URL for grid/thumbnail
  String get thumbnailDisplayUrl => smallUrl ?? thumbnailUrl ?? mediaUrl;

  bool get isVideo => mediaType == 'video';
  bool get isImage => mediaType == 'image';
}

// ─── POST USER MODEL ────────────────────────────────────────
class PostUserModel {
  final String id;
  final String username;
  final String fullName;
  final String? profilePicUrl;
  final bool isVerified;

  const PostUserModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.profilePicUrl,
    required this.isVerified,
  });

  factory PostUserModel.fromJson(Map<String, dynamic> json) {
    return PostUserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? '',
      profilePicUrl: json['profile_pic_url'],
      isVerified: json['is_verified'] ?? false,
    );
  }
}

// ─── POST MODEL ─────────────────────────────────────────────
class PostModel {
  final String id;
  final String? caption;
  final String? location;
  final List<PostMediaModel> media;
  final PostUserModel? user;
  final List<String> hashtags;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final bool isLiked;
  final bool isSaved;
  final bool isOwnPost;
  final bool commentsDisabled;
  final DateTime? createdAt;

  const PostModel({
    required this.id,
    this.caption,
    this.location,
    required this.media,
    this.user,
    required this.hashtags,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.isLiked,
    required this.isSaved,
    required this.isOwnPost,
    required this.commentsDisabled,
    this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] ?? '',
      caption: json['caption'],
      location: json['location'],
      media: (json['media'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PostMediaModel.fromJson)
          .toList(),
      user: json['user'] != null
          ? PostUserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      hashtags: List<String>.from(json['hashtags'] ?? []),
      likeCount: _asInt(json['like_count']),
      commentCount: _asInt(json['comment_count']),
      saveCount: _asInt(json['save_count']),
      isLiked: json['is_liked'] ?? false,
      isSaved: json['is_saved'] ?? false,
      isOwnPost: json['is_own_post'] ?? false,
      commentsDisabled: json['comments_disabled'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  // Create a copy with modified fields
  // Used for optimistic UI updates
  PostModel copyWith({
    int? likeCount,
    int? commentCount,
    int? saveCount,
    bool? isLiked,
    bool? isSaved,
  }) {
    return PostModel(
      id: id,
      caption: caption,
      location: location,
      media: media,
      user: user,
      hashtags: hashtags,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      saveCount: saveCount ?? this.saveCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isOwnPost: isOwnPost,
      commentsDisabled: commentsDisabled,
      createdAt: createdAt,
    );
  }

  // First media item
  PostMediaModel? get firstMedia => media.isNotEmpty ? media.first : null;

  // Has multiple images (carousel)
  bool get isCarousel => media.length > 1;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
