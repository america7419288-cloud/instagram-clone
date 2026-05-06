// lib/features/messages/data/models/conversation_model.dart

// ─── CONVERSATION USER (other person in DM) ─────────────────
class ConversationUserModel {
  final String id;
  final String username;
  final String? fullName;
  final String? profilePicUrl;
  final bool isVerified;

  const ConversationUserModel({
    required this.id,
    required this.username,
    this.fullName,
    this.profilePicUrl,
    required this.isVerified,
  });

  factory ConversationUserModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConversationUserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      fullName: json['full_name'],
      profilePicUrl: json['profile_pic_url'],
      isVerified: json['is_verified'] ?? false,
    );
  }
}

// ─── CONVERSATION MODEL ─────────────────────────────────────
class ConversationModel {
  final String id;
  final bool isGroup;
  final String? name;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final ConversationUserModel? otherUser;
  final List<ConversationUserModel> participants;
  final DateTime? createdAt;

  const ConversationModel({
    required this.id,
    required this.isGroup,
    this.name,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
    this.otherUser,
    required this.participants,
    this.createdAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final participantsJson =
        json['participants'] as List<dynamic>? ?? [];
    final otherUserJson = json['other_user'];

    return ConversationModel(
      id: json['id'] ?? '',
      isGroup: json['is_group'] ?? false,
      name: json['name'],
      avatarUrl: json['avatar_url'],
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      otherUser: otherUserJson != null
          ? ConversationUserModel.fromJson(
              otherUserJson as Map<String, dynamic>,
            )
          : null,
      participants: participantsJson
          .map((p) => ConversationUserModel.fromJson(
                p as Map<String, dynamic>,
              ))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  // Display name for the conversation
  String get displayName {
    if (isGroup) return name ?? 'Group Chat';
    return otherUser?.username ?? name ?? 'Unknown';
  }

  // Display avatar URL
  String? get displayAvatarUrl {
    if (isGroup) return avatarUrl;
    return otherUser?.profilePicUrl;
  }
}

