class MentionModel {
  final String userId;
  final String username;
  final String? avatarUrl;
  final bool isVerified;
  final int offset;
  final int length;

  MentionModel({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.isVerified = false,
    required this.offset,
    required this.length,
  });

  factory MentionModel.fromJson(Map<String, dynamic> json) {
    return MentionModel(
      userId: json['userId'] ?? json['user_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'] ?? json['profile_pic_url'],
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      offset: json['offset'] ?? 0,
      length: json['length'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'isVerified': isVerified,
      'offset': offset,
      'length': length,
    };
  }

  MentionModel copyWith({
    String? userId,
    String? username,
    String? avatarUrl,
    bool? isVerified,
    int? offset,
    int? length,
  }) {
    return MentionModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      offset: offset ?? this.offset,
      length: length ?? this.length,
    );
  }
}
