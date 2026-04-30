class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.bio,
    this.website,
    this.profilePicUrl,
    this.gender,
    this.isPrivate = false,
    this.isVerified = false,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: (json['full_name'] ?? json['fullName'])?.toString() ?? '',
      bio: json['bio']?.toString(),
      website: json['website']?.toString(),
      profilePicUrl: json['profile_pic_url']?.toString(),
      gender: json['gender']?.toString(),
      isPrivate: json['is_private'] == true,
      isVerified: json['is_verified'] == true,
      isActive: json['is_active'] != false,
    );
  }

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
}
