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

  @HiveField(8)
  final ChatUser? otherUser;

  // Phase 2 fields (not in Hive)
  final int? disappearingDuration;
  final bool isAccepted;

  // Phase 4 fields (not in Hive)
  final bool isMuted;
  final bool isUnread;
  final DateTime? mutedUntil;
  final DateTime? deletedAt;
  final bool? onlyAdminsCanSend;
  final bool? onlyAdminsCanAddMembers;
  final bool? onlyAdminsCanEditInfo;
  final bool? approvalRequired;

  Conversation({
    required this.id,
    this.isGroup = false,
    this.name,
    this.avatarUrl,
    this.lastMessage,
    this.unreadCount = 0,
    required this.participants,
    required this.updatedAt,
    this.otherUser,
    this.disappearingDuration,
    this.isAccepted = true,
    this.isMuted = false,
    this.isUnread = false,
    this.mutedUntil,
    this.deletedAt,
    this.onlyAdminsCanSend = false,
    this.onlyAdminsCanAddMembers = false,
    this.onlyAdminsCanEditInfo = false,
    this.approvalRequired = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      isGroup: json['is_group'] ?? json['isGroup'] ?? false,
      name: json['name'],
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      lastMessage: json['last_message'] != null
          ? Message.fromJson(json['last_message'])
          : json['lastMessage'] != null
              ? Message.fromJson(json['lastMessage'])
              : null,
      unreadCount: json['unread_count'] ?? json['unreadCount'] ?? 0,
      participants: (json['participants'] as List? ?? [])
          .map((p) => ChatUser.fromJson(p))
          .toList(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'])
              : DateTime.now(),
      otherUser: json['other_user'] != null
          ? ChatUser.fromJson(json['other_user'])
          : json['otherUser'] != null
              ? ChatUser.fromJson(json['otherUser'])
              : null,
      disappearingDuration: json['disappearing_duration'] != null
          ? int.tryParse(json['disappearing_duration'].toString())
          : json['disappearingDuration'] != null
              ? int.tryParse(json['disappearingDuration'].toString())
              : null,
      isAccepted: json['is_accepted'] ?? json['isAccepted'] ?? true,
      isMuted: json['is_muted'] ?? json['isMuted'] ?? false,
      isUnread: json['is_unread'] ?? json['isUnread'] ?? false,
      mutedUntil: json['muted_until'] != null
          ? DateTime.tryParse(json['muted_until'].toString())
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
      onlyAdminsCanSend: json['only_admins_can_send'] ?? json['onlyAdminsCanSend'] ?? false,
      onlyAdminsCanAddMembers: json['only_admins_can_add_members'] ?? json['onlyAdminsCanAddMembers'] ?? false,
      onlyAdminsCanEditInfo: json['only_admins_can_edit_info'] ?? json['onlyAdminsCanEditInfo'] ?? false,
      approvalRequired: json['approval_required'] ?? json['approvalRequired'] ?? false,
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
    ChatUser? otherUser,
    int? disappearingDuration,
    bool? isAccepted,
    bool? isMuted,
    bool? isUnread,
    DateTime? mutedUntil,
    DateTime? deletedAt,
    bool? onlyAdminsCanSend,
    bool? onlyAdminsCanAddMembers,
    bool? onlyAdminsCanEditInfo,
    bool? approvalRequired,
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
      otherUser: otherUser ?? this.otherUser,
      disappearingDuration: disappearingDuration ?? this.disappearingDuration,
      isAccepted: isAccepted ?? this.isAccepted,
      isMuted: isMuted ?? this.isMuted,
      isUnread: isUnread ?? this.isUnread,
      mutedUntil: mutedUntil ?? this.mutedUntil,
      deletedAt: deletedAt ?? this.deletedAt,
      onlyAdminsCanSend: onlyAdminsCanSend ?? this.onlyAdminsCanSend,
      onlyAdminsCanAddMembers: onlyAdminsCanAddMembers ?? this.onlyAdminsCanAddMembers,
      onlyAdminsCanEditInfo: onlyAdminsCanEditInfo ?? this.onlyAdminsCanEditInfo,
      approvalRequired: approvalRequired ?? this.approvalRequired,
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
      'other_user': otherUser?.toJson(),
      'disappearing_duration': disappearingDuration,
      'is_accepted': isAccepted,
      'is_muted': isMuted,
      'is_unread': isUnread,
      'muted_until': mutedUntil?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'only_admins_can_send': onlyAdminsCanSend,
    };
  }
}
