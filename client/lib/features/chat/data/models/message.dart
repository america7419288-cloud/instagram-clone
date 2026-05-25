import 'package:hive_ce/hive.dart';
import '../../models/message.dart' as mock;
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

  @HiveField(19)
  final String? sharedUsername;
  
  @HiveField(20)
  final String? sharedCaption;
  
  @HiveField(21)
  final String? sharedThumbnailUrl;

  @HiveField(22)
  final String? thumbnailUrl;

  // Transient: local file path for optimistic media preview (not persisted)
  final String? localPath;

  // Phase 2 fields (not in Hive)
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime? expiresAt;

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
    this.sharedUsername,
    this.sharedCaption,
    this.sharedThumbnailUrl,
    this.thumbnailUrl,
    this.localPath,
    this.isEdited = false,
    this.editedAt,
    this.expiresAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] != null
        ? ChatUser.fromJson(json['sender'])
        : null;

    // Handle polymorphic shared content
    String? sUsername;
    String? sCaption;
    String? sThumbnail;
    String? sPostId;

    final sharedPostData = json['shared_post'] ?? json['sharedPost'];
    final sharedReelData = json['shared_reel'] ?? json['sharedReel'];
    final sharedStoryData = json['shared_story'] ?? json['sharedStory'];

    if (sharedPostData != null) {
      sUsername = sharedPostData['user']?['username'];
      sCaption = sharedPostData['caption'];
      sPostId = sharedPostData['id']?.toString();
      sThumbnail = sharedPostData['thumbnail'] ?? sharedPostData['thumbnailUrl'];
      if (sThumbnail == null && sharedPostData['mediaFiles'] != null) {
        final mediaFiles = sharedPostData['mediaFiles'] as List;
        if (mediaFiles.isNotEmpty) {
          sThumbnail = mediaFiles[0]['thumbnailUrl'] ?? mediaFiles[0]['url'];
        }
      }
    } else if (sharedReelData != null) {
      sUsername = sharedReelData['user']?['username'];
      sCaption = sharedReelData['caption'];
      sPostId = sharedReelData['id']?.toString();
      sThumbnail = sharedReelData['thumbnail'] ?? sharedReelData['thumbnailUrl'];
    } else if (sharedStoryData != null) {
      sUsername = sharedStoryData['user']?['username'];
      sPostId = sharedStoryData['id']?.toString();
      sThumbnail = sharedStoryData['thumbnail'] ?? sharedStoryData['thumbnailUrl'];
    }

    final String? sharedPostId = json['shared_post_id'] ?? json['postId'] ?? sPostId;

    return Message(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? json['conversationId'] ?? '',
      senderId: json['sender_id'] ?? json['senderId'] ?? sender?.id ?? '',
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? json['messageType'] ?? 'text',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      isDeleted: json['is_deleted'] ?? json['isDeleted'] ?? false,
      mediaUrl: json['media_url'] ?? json['mediaUrl'],
      sender: sender,
      tempId: json['temp_id'] ?? json['tempId'],
      postId: (json['message_type'] ?? json['messageType']) == 'post' ? sharedPostId : (json['postId'] ?? json['post_id']),
      reelId: (json['message_type'] ?? json['messageType']) == 'reel' ? sharedPostId : (json['reelId'] ?? json['reel_id']),
      storyId: (json['message_type'] ?? json['messageType']) == 'story' ? sharedPostId : (json['storyId'] ?? json['story_id']),
      reactions: json['reactions'] != null
          ? Map<String, int>.from(json['reactions'])
          : null,
      replyToId: json['reply_to_id'] ?? json['replyToId'],
      replyToMessage: json['reply_to_message'] != null
          ? Message.fromJson(json['reply_to_message'])
          : json['replyToMessage'] != null
              ? Message.fromJson(json['replyToMessage'])
              : null,
      sharedUsername: sUsername,
      sharedCaption: sCaption,
      sharedThumbnailUrl: sThumbnail,
      thumbnailUrl: json['thumbnail_url'] ?? json['thumbnailUrl'],
      isEdited: json['is_edited'] ?? json['isEdited'] ?? false,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'])
          : json['editedAt'] != null
              ? DateTime.parse(json['editedAt'])
              : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : json['expiresAt'] != null
              ? DateTime.parse(json['expiresAt'])
              : null,
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
    String? sharedUsername,
    String? sharedCaption,
    String? sharedThumbnailUrl,
    String? thumbnailUrl,
    bool? isEdited,
    DateTime? editedAt,
    DateTime? expiresAt,
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
      sharedUsername: sharedUsername ?? this.sharedUsername,
      sharedCaption: sharedCaption ?? this.sharedCaption,
      sharedThumbnailUrl: sharedThumbnailUrl ?? this.sharedThumbnailUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      localPath: localPath ?? this.localPath,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      expiresAt: expiresAt ?? this.expiresAt,
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
      'sharedUsername': sharedUsername,
      'sharedCaption': sharedCaption,
      'sharedThumbnailUrl': sharedThumbnailUrl,
      'thumbnail_url': thumbnailUrl,
      'is_edited': isEdited,
      'edited_at': editedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  mock.ChatMessage toChatMessage({required bool isMe}) {
    return mock.ChatMessage(
      id: id.isEmpty ? (tempId ?? '') : id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: sender?.username ?? 'User',
      senderAvatar: sender?.profilePicUrl,
      type: _mapMessageType(messageType),
      text: content,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      sharedUsername: sharedUsername,
      sharedCaption: sharedCaption,
      sharedPostId: postId,
      sharedThumbnailUrl: sharedThumbnailUrl,
      timestamp: createdAt,
      status: _mapStatus(),
      isFromMe: isMe,
      isDeleted: isDeleted,
    );
  }

  mock.MessageType _mapMessageType(String type) {
    switch (type) {
      case 'text':
        return mock.MessageType.text;
      case 'image':
        return mock.MessageType.image;
      case 'video':
        return mock.MessageType.video;
      case 'audio':
        return mock.MessageType.audio;
      case 'reel':
        return mock.MessageType.reel;
      case 'post':
        return mock.MessageType.post;
      case 'story':
        return mock.MessageType.storyReply;
      case 'like':
        return mock.MessageType.text;
      default:
        return mock.MessageType.text;
    }
  }

  mock.MessageStatus _mapStatus() {
    if (isSending) return mock.MessageStatus.sending;
    if (hasError) return mock.MessageStatus.failed;
    if (isRead) return mock.MessageStatus.seen;
    return mock.MessageStatus.sent; // Default to sent
  }
} 