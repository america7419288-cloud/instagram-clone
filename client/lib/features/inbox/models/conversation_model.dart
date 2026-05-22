// lib/features/inbox/models/conversation_model.dart

enum ConversationState {
  unread,
  read,
  muted,
  requested,
  failed,
  sending,
}

enum LastMessageType {
  text, image, reel, post,
  story, voice, gif, like,
}

class ConversationModel {
  final String id;
  final String userId;
  final String username;
  final String avatarUrl;
  final bool isVerified;
  final bool isGroup;
  final List<String> groupAvatars;
  final String lastMessage;
  final LastMessageType lastMessageType;
  final DateTime lastMessageTime;
  final bool isSentByMe;
  final int unreadCount;
  final bool isActive;
  final DateTime? lastActiveTime;
  final bool isMuted;
  final bool hasStory;
  final bool isTyping;
  final ConversationState state;

  const ConversationModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    this.isVerified = false,
    this.isGroup = false,
    this.groupAvatars = const [],
    required this.lastMessage,
    this.lastMessageType = LastMessageType.text,
    required this.lastMessageTime,
    this.isSentByMe = false,
    this.unreadCount = 0,
    this.isActive = false,
    this.lastActiveTime,
    this.isMuted = false,
    this.hasStory = false,
    this.isTyping = false,
    this.state = ConversationState.read,
  });

  bool get isUnread => 
    unreadCount > 0 && state == ConversationState.unread;

  String get timeDisplay {
    final now = DateTime.now();
    final diff = now.difference(lastMessageTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) {
      const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return days[lastMessageTime.weekday - 1];
    }
    return '${lastMessageTime.month}/${lastMessageTime.day}';
  }

  String get lastMessagePreview {
    final prefix = isSentByMe ? 'You: ' : '';
    switch (lastMessageType) {
      case LastMessageType.image: return '${prefix}📷 Photo';
      case LastMessageType.reel:  return '${prefix}🎬 Reel';
      case LastMessageType.post:  return '${prefix}📮 Post';
      case LastMessageType.voice: return '${prefix}🎤 Voice message';
      case LastMessageType.story: return '${prefix}↩ Replied to story';
      case LastMessageType.gif:   return '${prefix}GIF';
      case LastMessageType.like:  return '${prefix}❤️ Liked a message';
      default: return '$prefix$lastMessage';
    }
  }

  String get activeStatus {
    if (isActive) return 'Active now';
    if (lastActiveTime == null) return '';
    final diff = DateTime.now().difference(lastActiveTime!);
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    return '';
  }

  ConversationModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? avatarUrl,
    bool? isVerified,
    bool? isGroup,
    List<String>? groupAvatars,
    String? lastMessage,
    LastMessageType? lastMessageType,
    DateTime? lastMessageTime,
    bool? isSentByMe,
    int? unreadCount,
    bool? isActive,
    DateTime? lastActiveTime,
    bool? isMuted,
    bool? hasStory,
    bool? isTyping,
    ConversationState? state,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      isGroup: isGroup ?? this.isGroup,
      groupAvatars: groupAvatars ?? this.groupAvatars,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isSentByMe: isSentByMe ?? this.isSentByMe,
      unreadCount: unreadCount ?? this.unreadCount,
      isActive: isActive ?? this.isActive,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      isMuted: isMuted ?? this.isMuted,
      hasStory: hasStory ?? this.hasStory,
      isTyping: isTyping ?? this.isTyping,
      state: state ?? this.state,
    );
  }
}
