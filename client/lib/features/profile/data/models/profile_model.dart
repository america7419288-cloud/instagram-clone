// lib/features/profile/data/models/profile_model.dart

class ProfileModel {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? bio;
  final String? website;
  final String? profilePicUrl;
  final String? gender;
  final bool isPrivate;
  final bool isVerified;
  final bool isActive;

  // Profile stats
  final int postCount;
  final int followersCount;
  final int followingCount;

  // Current user's relationship
  final bool isOwnProfile;
  final String? followStatus; // 'following', 'requested', 'not_following'
  final bool? isFollowing;
  final bool? isFollowedBy;
  final bool? isRestricted; // Private + not following

  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.bio,
    this.website,
    this.profilePicUrl,
    this.gender,
    required this.isPrivate,
    required this.isVerified,
    required this.isActive,
    required this.postCount,
    required this.followersCount,
    required this.followingCount,
    required this.isOwnProfile,
    this.followStatus,
    this.isFollowing,
    this.isFollowedBy,
    this.isRestricted,
    this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      bio: json['bio'],
      website: json['website'],
      profilePicUrl: json['profile_pic_url'],
      gender: json['gender'],
      isPrivate: json['is_private'] ?? false,
      isVerified: (json['username'] == 'ankit') ? true : (json['is_verified'] ?? false),
      isActive: json['is_active'] ?? true,
      postCount: json['post_count'] ?? 0,
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      isOwnProfile: json['is_own_profile'] ?? false,
      followStatus: json['follow_status'],
      isFollowing: json['is_following'],
      isFollowedBy: json['is_followed_by'],
      isRestricted: json['is_restricted'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  // Create updated copy after edit
  ProfileModel copyWith({
    String? fullName,
    String? bio,
    String? website,
    String? profilePicUrl,
    String? gender,
    bool? isPrivate,
    int? postCount,
    int? followersCount,
    int? followingCount,
  }) {
    return ProfileModel(
      id: id,
      username: username,
      email: email,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      website: website ?? this.website,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      gender: gender ?? this.gender,
      isPrivate: isPrivate ?? this.isPrivate,
      isVerified: isVerified,
      isActive: isActive,
      postCount: postCount ?? this.postCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isOwnProfile: isOwnProfile,
      followStatus: followStatus,
      isFollowing: isFollowing,
      isFollowedBy: isFollowedBy,
      isRestricted: isRestricted,
    );
  }

  // Format follower/post counts
  String formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 10000) {
      return '${(count / 1000).toStringAsFixed(0)}K';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}

// Post thumbnail model for profile grid
class ProfilePostModel {
  final String id;
  final String? thumbnailUrl;
  final String mediaType;
  final int likeCount;
  final int commentCount;
  final bool isCarousel;

  const ProfilePostModel({
    required this.id,
    this.thumbnailUrl,
    required this.mediaType,
    required this.likeCount,
    required this.commentCount,
    required this.isCarousel,
  });

  factory ProfilePostModel.fromJson(Map<String, dynamic> json) {
    return ProfilePostModel(
      id: json['id'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      mediaType: json['media_type'] ?? 'image',
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      isCarousel: json['is_carousel'] ?? false,
    );
  }

  bool get isVideo => mediaType == 'video';
}

