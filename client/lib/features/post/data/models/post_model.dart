// lib/features/post/data/models/post_model.dart

import 'package:flutter/foundation.dart';
import '../../../profile/data/models/profile_model.dart';

// ─────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────
enum PostAudience { everyone, followers, closeFriends, onlyMe }
enum PostType { image, video, carousel }

// ─────────────────────────────────────────────────────
// POST MEDIA MODEL
// ─────────────────────────────────────────────────────
class PostMediaModel {
  final String id;
  final String url;
  final String? thumbnailUrl;  // ← NEW: for videos
  final String mediaType;      // ← NEW: 'image' | 'video'
  final int? duration;         // ← NEW: seconds (videos only)
  final int? width;
  final int? height;
  final int order;

  const PostMediaModel({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    this.mediaType = 'image',
    this.duration,
    this.width,
    this.height,
    this.order = 0,
  });

  // ─── Helpers ─────────────────────────────────────────
  bool get isVideo => mediaType == 'video';
  bool get isImage => mediaType == 'image';
  String get feedUrl => url;

  // Duration formatted as "0:45" or "1:05"
  String get durationFormatted {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory PostMediaModel.fromJson(Map<String, dynamic> json) {
    return PostMediaModel(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? json['media_url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? json['small_url']?.toString() ?? json['thumbnai_url']?.toString(),
      mediaType: json['media_type']?.toString() ?? json['mediaType']?.toString() ?? 'image',
      duration: json['duration'] != null
          ? int.tryParse(json['duration'].toString())
          : null,
      width: json['width'] != null
          ? int.tryParse(json['width'].toString())
          : null,
      height: json['height'] != null
          ? int.tryParse(json['height'].toString())
          : null,
      order: json['order'] != null
          ? int.tryParse(json['order'].toString()) ?? 0
          : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'thumbnailUrl': thumbnailUrl,
        'mediaType': mediaType,
        'duration': duration,
        'width': width,
        'height': height,
        'order': order,
      };

  PostMediaModel copyWith({
    String? id,
    String? url,
    String? thumbnailUrl,
    String? mediaType,
    int? duration,
    int? width,
    int? height,
    int? order,
  }) {
    return PostMediaModel(
      id: id ?? this.id,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mediaType: mediaType ?? this.mediaType,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      order: order ?? this.order,
    );
  }
}

// ─────────────────────────────────────────────────────
// POST MODEL
// ─────────────────────────────────────────────────────
class PostModel {
  final String id;
  final String userId;
  final String username;
  final String? fullName;
  final String? userAvatar;
  final bool isVerified;
  final String? caption;
  final String? location;
  final List<PostMediaModel> mediaFiles;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isSaved;
  final bool hasVideo;       // ← NEW: any media is video
  final bool hasMultiple;    // ← NEW: carousel post
  final bool isOwnPost;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Extra fields used in UI
  final bool hasStory;

  // Toggleable settings
  final bool isPinned;
  final bool isArchived;
  final bool hideLikesCount;
  final bool commentsDisabled;
  final PostAudience audience;

  // Music Metadata
  final String? musicId;
  final String? musicTitle;
  final String? musicArtist;
  final int? musicStartTime;
  final int? musicDuration;

  const PostModel({
    required this.id,
    required this.userId,
    required this.username,
    this.fullName,
    this.userAvatar,
    this.isVerified = false,
    this.caption,
    this.location,
    this.mediaFiles = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.hasVideo = false,
    this.hasMultiple = false,
    this.isOwnPost = false,
    required this.createdAt,
    required this.updatedAt,
    this.hasStory = false,
    this.isPinned = false,
    this.isArchived = false,
    this.hideLikesCount = false,
    this.commentsDisabled = false,
    this.audience = PostAudience.everyone,
    this.musicId,
    this.musicTitle,
    this.musicArtist,
    this.musicStartTime,
    this.musicDuration,
  });

  factory PostModel.fromProfilePost(ProfilePostModel p) {
    return PostModel(
      id: p.id,
      userId: '',
      username: '',
      mediaFiles: [
        PostMediaModel(
          id: p.id,
          url: p.thumbnailUrl ?? '',
          mediaType: p.mediaType,
        ),
      ],
      likesCount: p.likeCount,
      commentsCount: p.commentCount,
      hasVideo: p.isVideo,
      hasMultiple: p.isCarousel,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ─── Compatibility Getters (Backward Compatibility) ───────
  int get likeCount => likesCount;
  int get commentCount => commentsCount;
  List<PostMediaModel> get media => mediaFiles;
  bool get isCarousel => hasMultiple;
  bool get hasActiveStory => hasStory;

  PostType get type => hasVideo ? PostType.video : (hasMultiple ? PostType.carousel : PostType.image);

  // User object shim
  ProfileModel? get user => ProfileModel(
        id: userId,
        username: username,
        email: '',
        fullName: fullName ?? '',
        profilePicUrl: userAvatar,
        isVerified: isVerified,
        isPrivate: false,
        isActive: true,
        postCount: 0,
        followersCount: 0,
        followingCount: 0,
        isOwnProfile: false,
      );

  // ─── Helpers ─────────────────────────────────────────
  PostMediaModel? get firstMedia =>
      mediaFiles.isNotEmpty ? mediaFiles.first : null;

  String? get coverUrl {
    final first = firstMedia;
    if (first == null) return null;
    // For videos: use thumbnail; for images: use url
    if (first.isVideo) return first.thumbnailUrl ?? first.url;
    return first.url;
  }

  // Helper for edit post horizontal preview matching design
  List<String> get mediaUrls => mediaFiles.map((m) => m.url).toList();

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Handle both snake_case and camelCase for mediaFiles
    final mediaRaw = json['mediaFiles'] ?? json['media'] ?? [];
    final mediaList = (mediaRaw as List<dynamic>)
        .map((m) => PostMediaModel.fromJson(m as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return PostModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? json['user']?['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['user']?['full_name']?.toString(),
      userAvatar: json['userAvatar']?.toString() ?? json['user']?['profile_pic_url']?.toString(),
      isVerified: json['isVerified'] == true || json['user']?['is_verified'] == true,
      caption: json['caption']?.toString() ?? '',
      location: json['location']?.toString(),
      mediaFiles: mediaList,
      likesCount: int.tryParse((json['likesCount'] ?? json['like_count'] ?? json['likes_count'] ?? json['likeCount'] ?? '0').toString()) ?? 0,
      commentsCount:
          int.tryParse((json['commentsCount'] ?? json['comment_count'] ?? json['comments_count'] ?? json['commentCount'] ?? '0').toString()) ?? 0,
      isLiked: json['isLiked'] == true || json['is_liked'] == true,
      isSaved: json['isSaved'] == true || json['is_saved'] == true,
      hasVideo: json['hasVideo'] == true ||
          mediaList.any((m) => m.isVideo),
      hasMultiple: json['hasMultiple'] == true || mediaList.length > 1,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ??
              DateTime.now()
          : (json['created_at'] != null 
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      isOwnPost: json['isOwnPost'] == true || json['is_own_post'] == true,
      hasStory: json['hasStory'] == true,
      isPinned: json['isPinned'] == true,
      isArchived: json['isArchived'] == true,
      hideLikesCount: json['hideLikesCount'] == true,
      commentsDisabled: json['commentsDisabled'] == true || json['comments_disabled'] == true,
      audience: PostAudience.values.firstWhere(
        (a) => PostAudience.values.any((val) => val.name == json['audience']) && a.name == json['audience'],
        orElse: () => PostAudience.everyone,
      ),
      
      // Music Metadata (Nested object from server)
      musicId: json['music']?['id']?.toString() ?? json['music_id']?.toString() ?? json['musicId']?.toString(),
      musicTitle: json['music']?['title']?.toString() ?? json['music_title']?.toString() ?? json['musicTitle']?.toString(),
      musicArtist: json['music']?['artist']?.toString() ?? json['music_artist']?.toString() ?? json['musicArtist']?.toString(),
      musicStartTime: json['music']?['startTime'] != null 
          ? int.tryParse(json['music']['startTime'].toString()) 
          : (json['music_start_time'] != null ? int.tryParse(json['music_start_time'].toString()) : null),
      musicDuration: json['music']?['duration'] != null 
          ? int.tryParse(json['music']['duration'].toString()) 
          : (json['music_duration'] != null ? int.tryParse(json['music_duration'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'username': username,
        'fullName': fullName,
        'userAvatar': userAvatar,
        'isVerified': isVerified,
        'caption': caption,
        'location': location,
        'mediaFiles': mediaFiles.map((m) => m.toJson()).toList(),
        'likesCount': likesCount,
        'commentsCount': commentsCount,
        'isLiked': isLiked,
        'isSaved': isSaved,
        'hasVideo': hasVideo,
        'hasMultiple': hasMultiple,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isOwnPost': isOwnPost,
        'hasStory': hasStory,
        'isPinned': isPinned,
        'isArchived': isArchived,
        'hideLikesCount': hideLikesCount,
        'commentsDisabled': commentsDisabled,
        'audience': audience.name,
        'musicId': musicId,
        'musicTitle': musicTitle,
        'musicArtist': musicArtist,
        'musicStartTime': musicStartTime,
        'musicDuration': musicDuration,
      };

  PostModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? fullName,
    String? userAvatar,
    bool? isVerified,
    String? caption,
    String? location,
    List<PostMediaModel>? mediaFiles,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    bool? isSaved,
    bool? hasVideo,
    bool? hasMultiple,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasStory,
    bool? isPinned,
    bool? isArchived,
    bool? hideLikesCount,
    bool? commentsDisabled,
    PostAudience? audience,
    int? likeCount, // Compatibility
    int? commentCount, // Compatibility
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      userAvatar: userAvatar ?? this.userAvatar,
      isVerified: isVerified ?? this.isVerified,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      mediaFiles: mediaFiles ?? this.mediaFiles,
      likesCount: likeCount ?? likesCount ?? this.likesCount,
      commentsCount: commentCount ?? commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      hasVideo: hasVideo ?? this.hasVideo,
      hasMultiple: hasMultiple ?? this.hasMultiple,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOwnPost: isOwnPost ?? this.isOwnPost,
      hasStory: hasStory ?? this.hasStory,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      hideLikesCount: hideLikesCount ?? this.hideLikesCount,
      commentsDisabled: commentsDisabled ?? this.commentsDisabled,
      audience: audience ?? this.audience,
      musicId: musicId ?? this.musicId,
      musicTitle: musicTitle ?? this.musicTitle,
      musicArtist: musicArtist ?? this.musicArtist,
      musicStartTime: musicStartTime ?? this.musicStartTime,
      musicDuration: musicDuration ?? this.musicDuration,
    );
  }
}
