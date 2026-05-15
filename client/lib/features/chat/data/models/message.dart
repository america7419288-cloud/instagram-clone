import 'package:hive_ce/hive.dart';
import 'chat_user.dart';

part 'message.g.dart';

@HiveType(typeId: 1)
class Message {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String conversationId;
  
  @HiveField(2)
  final String senderId;
  
  @HiveField(3)
  final String content;
  
  @HiveField(4)
  final String messageType; // text, image, video, like
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  final bool isRead;
  
  @HiveField(7)
  final bool isDeleted;
  
  @HiveField(8)
  final String? mediaUrl;
  
  @HiveField(9)
  final ChatUser? sender;
  
  // Local-only fields (not in Hive or at least handled carefully)
  @HiveField(10)
  final bool isSending;
  
  @HiveField(11)
  final bool hasError;
  
  @HiveField(12)
  final String? tempId;
  
  @HiveField(13)
  final String? postId;
  
  @HiveField(14)
  final String? reelId;
  
  @HiveField(15)
  final String? storyId;

  @HiveField(16)
  final Map<String, int>? reactions;

  @HiveField(17)
  final String? replyToId;

  @HiveField(18)
  final Message? replyToMessage;

  // Transient: local file path for optimistic media preview (not persisted)
  final String? localPath;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    required this.createdAt,
    this.isRead = false,
    this.isDeleted = false,
    this.mediaUrl,
    this.sender,
    this.isSending = false,
    this.hasError = false,
    this.tempId,
    this.postId,
    this.reelId,
    this.storyId,
    this.reactions,
    this.replyToId,
    this.replyToMessage,
    this.localPath,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? 'text',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      isRead: json['is_read'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      mediaUrl: json['media_url'],
      sender: json['sender'] != null ? ChatUser.fromJson(json['sender']) : null,
      tempId: json['temp_id'],
      postId: json['postId'],
      reelId: json['reelId'],
      storyId: json['storyId'],
      reactions: json['reactions'] != null ? Map<String, int>.from(json['reactions']) : null,
      replyToId: json['reply_to_id'],
      replyToMessage: json['reply_to_message'] != null 
          ? Message.fromJson(json['reply_to_message']) 
          : null,
      // localPath not from JSON
    );
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    String? messageType,
    DateTime? createdAt,
    bool? isRead,
    bool? isDeleted,
    String? mediaUrl,
    ChatUser? sender,
    bool? isSending,
    bool? hasError,
    String? tempId,
    String? postId,
    String? reelId,
    String? storyId,
    Map<String, int>? reactions,
    String? replyToId,
    Message? replyToMessage,
    String? localPath,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isDeleted: isDeleted ?? this.isDeleted,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      sender: sender ?? this.sender,
      isSending: isSending ?? this.isSending,
      hasError: hasError ?? this.hasError,
      tempId: tempId ?? this.tempId,
      postId: postId ?? this.postId,
      reelId: reelId ?? this.reelId,
      storyId: storyId ?? this.storyId,
      reactions: reactions ?? this.reactions,
      replyToId: replyToId ?? this.replyToId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      localPath: localPath ?? this.localPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'is_deleted': isDeleted,
      'media_url': mediaUrl,
      'sender': sender?.toJson(),
      'temp_id': tempId,
      'postId': postId,
      'reelId': reelId,
      'storyId': storyId,
      'reactions': reactions,
      'reply_to_id': replyToId,
      'reply_to_message': replyToMessage?.toJson(),
    };
  }

}
