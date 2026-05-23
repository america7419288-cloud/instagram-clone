import '../../../chat/data/models/chat_user.dart';

class CommunityMember {
  final String id;
  final String communityId;
  final String userId;
  final String role; // 'owner' | 'admin' | 'moderator' | 'member'
  final bool isMuted;
  final bool isBanned;
  final ChatUser? user;

  CommunityMember({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.role,
    required this.isMuted,
    required this.isBanned,
    this.user,
  });

  factory CommunityMember.fromJson(Map<String, dynamic> json) {
    return CommunityMember(
      id: json['id'] ?? '',
      communityId: json['community_id'] ?? '',
      userId: json['user_id'] ?? '',
      role: json['role'] ?? 'member',
      isMuted: json['is_muted'] ?? false,
      isBanned: json['is_banned'] ?? false,
      user: json['user'] != null ? ChatUser.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'community_id': communityId,
      'user_id': userId,
      'role': role,
      'is_muted': isMuted,
      'is_banned': isBanned,
    };
  }
}
