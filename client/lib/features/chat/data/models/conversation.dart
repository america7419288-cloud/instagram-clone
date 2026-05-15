import 'package:hive_ce/hive.dart';
import 'chat_user.dart';
import 'message.dart';

part 'conversation.g.dart';

@HiveType(typeId: 2)
class Conversation {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final bool isGroup;
  
  @HiveField(2)
  final String? name;
  
  @HiveField(3)
  final String? avatarUrl;
  
  @HiveField(4)
  final Message? lastMessage;
  
  @HiveField(5)
  final int unreadCount;
  
  @HiveField(6)
  final List<ChatUser> participants;
  
  @HiveField(7)
  final DateTime updatedAt;

  Conversation({
    required this.id,
    this.isGroup = false,
    this.name,
    this.avatarUrl,
    this.lastMessage,
    this.unreadCount = 0,
    required this.participants,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      isGroup: json['is_group'] ?? false,
      name: json['name'],
      avatarUrl: json['avatar_url'],
      lastMessage: json['last_message'] != null 
          ? Message.fromJson(json['last_message']) 
          : null,
      unreadCount: json['unread_count'] ?? 0,
      participants: (json['participants'] as List? ?? [])
          .map((p) => ChatUser.fromJson(p))
          .toList(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : DateTime.now(),
    );
  }

  Conversation copyWith({
    String? id,
    bool? isGroup,
    String? name,
    String? avatarUrl,
    Message? lastMessage,
    int? unreadCount,
    List<ChatUser>? participants,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      isGroup: isGroup ?? this.isGroup,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      participants: participants ?? this.participants,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_group': isGroup,
      'name': name,
      'avatar_url': avatarUrl,
      'last_message': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'participants': participants.map((p) => p.toJson()).toList(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ChatUser? get otherUser {
    if (isGroup) return null;
    // Assume we need to know who "we" are to find the other user,
    // or just return the first one that isn't the primary if available.
    // For now, return the first one as a placeholder if there are participants.
    return participants.isNotEmpty ? participants.first : null;
  }
}
