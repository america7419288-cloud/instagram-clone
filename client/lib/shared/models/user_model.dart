// lib/shared/models/user_model.dart

class UserModel {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? bio;
  final String? website;
  final String? profilePicUrl;
  final String? gender;
  final String? phoneNumber;

  String? get profilePicture => profilePicUrl;
  final bool isPrivate;
  final bool isVerified;
  final bool isActive;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;

  // Optional: for profile page
  final int? postCount;
  final int? followersCount;
  final int? followingCount;
  final bool? isFollowing;
  final bool? isOwnProfile;
  final String? followStatus;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.bio,
    this.website,
    this.profilePicUrl,
    this.gender,
    this.phoneNumber,
    required this.isPrivate,
    required this.isVerified,
    required this.isActive,
    this.lastActiveAt,
    this.createdAt,
    this.postCount,
    this.followersCount,
    this.followingCount,
    this.isFollowing,
    this.isOwnProfile,
    this.followStatus,
  });

  // ─── FROM JSON (API response → Dart object) ────────────
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      bio: json['bio'],
      website: json['website'],
      profilePicUrl: json['profile_pic_url'],
      gender: json['gender'],
      phoneNumber: json['phone_number'],
      isPrivate: json['is_private'] ?? false,
      isVerified: json['is_verified'] ?? false,
      isActive: json['is_active'] ?? true,
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      postCount: json['post_count'],
      followersCount: json['followers_count'],
      followingCount: json['following_count'],
      isFollowing: json['is_following'],
      isOwnProfile: json['is_own_profile'],
      followStatus: json['follow_status'],
    );
  }

  // ─── TO JSON (Dart object → Map) ───────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'bio': bio,
      'website': website,
      'profile_pic_url': profilePicUrl,
      'gender': gender,
      'phone_number': phoneNumber,
      'is_private': isPrivate,
      'is_verified': isVerified,
      'is_active': isActive,
      'last_active_at': lastActiveAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // ─── COPY WITH (create modified copy) ──────────────────
  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? bio,
    String? website,
    String? profilePicUrl,
    String? gender,
    String? phoneNumber,
    bool? isPrivate,
    bool? isVerified,
    bool? isActive,
    int? postCount,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
    bool? isOwnProfile,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      website: website ?? this.website,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPrivate: isPrivate ?? this.isPrivate,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      postCount: postCount ?? this.postCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isOwnProfile: isOwnProfile ?? this.isOwnProfile,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, email: $email)';
  }
}

// ─── AUTH RESPONSE MODEL ────────────────────────────────────
// What we get back from login/register API
class AuthResponseModel {
  final UserModel user;
  final String accessToken;
  final String refreshToken;
  final String expiresIn;

  const AuthResponseModel({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      user: UserModel.fromJson(json['user']),
      accessToken: json['tokens']['accessToken'] ?? '',
      refreshToken: json['tokens']['refreshToken'] ?? '',
      expiresIn: json['tokens']['expiresIn'] ?? '7d',
    );
  }
}
