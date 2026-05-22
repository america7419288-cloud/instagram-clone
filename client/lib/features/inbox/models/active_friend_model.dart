// lib/features/inbox/models/active_friend_model.dart

class ActiveFriendModel {
  final String id;
  final String username;
  final String avatarUrl;
  final bool hasActiveNote;
  final String? noteText;
  final bool isActive;
  final DateTime? lastActiveTime;
  final String conversationId;

  const ActiveFriendModel({
    required this.id,
    required this.username,
    required this.avatarUrl,
    this.hasActiveNote = false,
    this.noteText,
    this.isActive = false,
    this.lastActiveTime,
    required this.conversationId,
  });

  ActiveFriendModel copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    bool? hasActiveNote,
    String? noteText,
    bool? isActive,
    DateTime? lastActiveTime,
    String? conversationId,
  }) {
    return ActiveFriendModel(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      hasActiveNote: hasActiveNote ?? this.hasActiveNote,
      noteText: noteText ?? this.noteText,
      isActive: isActive ?? this.isActive,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}
