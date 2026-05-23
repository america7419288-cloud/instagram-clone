import '../../../chat/data/models/chat_user.dart';

class Community {
  final String id;
  final String name;
  final String handle;
  final String description;
  final String category;
  final String privacy; // 'public' | 'private'
  final String? avatarUrl;
  final String? coverUrl;
  final String createdBy;
  final int memberCount;
  final int maxMembers;
  final String? inviteLink;
  final Map<String, dynamic> settings;
  final List<String> tags;
  final bool isActive;
  final DateTime createdAt;
  final ChatUser? creator;

  Community({
    required this.id,
    required this.name,
    required this.handle,
    required this.description,
    required this.category,
    required this.privacy,
    this.avatarUrl,
    this.coverUrl,
    required this.createdBy,
    required this.memberCount,
    required this.maxMembers,
    this.inviteLink,
    required this.settings,
    required this.tags,
    required this.isActive,
    required this.createdAt,
    this.creator,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      handle: json['handle'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      privacy: json['privacy'] ?? 'public',
      avatarUrl: json['avatar_url'],
      coverUrl: json['cover_url'],
      createdBy: json['created_by'] ?? '',
      memberCount: json['member_count'] ?? 0,
      maxMembers: json['max_members'] ?? 20000,
      inviteLink: json['invite_link'],
      settings: json['settings'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['settings']) : {},
      tags: json['tags'] != null ? List<String>.from(json['tags']) : const [],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      creator: json['creator'] != null ? ChatUser.fromJson(json['creator']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'handle': handle,
      'description': description,
      'category': category,
      'privacy': privacy,
      'avatar_url': avatarUrl,
      'cover_url': coverUrl,
      'created_by': createdBy,
      'member_count': memberCount,
      'max_members': maxMembers,
      'invite_link': inviteLink,
      'settings': settings,
      'tags': tags,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
