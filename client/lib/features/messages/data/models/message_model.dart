// lib/features/messages/data/models/message_model.dart

// ─── MESSAGE SENDER ─────────────────────────────────────────
class MessageSenderModel {
  final String id;
  final String username;
  final String? profilePicUrl;

  const MessageSenderModel({
    required this.id,
    required this.username,
    this.profilePicUrl,
  });

  factory MessageSenderModel.fromJson(Map<String, dynamic> json) {
    return MessageSenderModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      profilePicUrl: json['profile_pic_url'],
    );
  }
}

// ─── REPLIED TO (preview of message being replied to) ───────
class RepliedToModel {
  final String id;
  final String? content;
  final bool isDeleted;
  final String senderId;

  const RepliedToModel({
    required this.id,
    this.content,
    required this.isDeleted,
    required this.senderId,
  });

  factory RepliedToModel.fromJson(Map<String, dynamic> json) {
    return RepliedToModel(
      id: json['id'] ?? '',
      content: json['content'],
      isDeleted: json['is_deleted'] ?? false,
      senderId: json['sender_id'] ?? '',
    );
  }

  String get displayContent {
    if (isDeleted) return 'This message was unsent';
    return content ?? '';
  }
}

// ─── MESSAGE MODEL ───────────────────────────────────────────
class MessageModel {
  final String id;
  final String conversationId;
  final String messageType; // text, image, video, like, etc.
  final String? content;
  final String? mediaUrl;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  // Who sent it
  final MessageSenderModel? sender;

  // If this is a reply
  final RepliedToModel? repliedTo;

  // Local-only fields
  final bool isSending;    // Currently being sent
  final bool hasError;     // Failed to send

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.messageType,
    this.content,
    this.mediaUrl,
    required this.isDeleted,
    this.deletedAt,
    this.createdAt,
    this.sender,
    this.repliedTo,
    this.isSending = false,
    this.hasError = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      messageType: json['message_type'] ?? 'text',
      content: json['content'],
      mediaUrl: json['media_url'],
      isDeleted: json['is_deleted'] ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      sender: json['sender'] != null
          ? MessageSenderModel.fromJson(
              json['sender'] as Map<String, dynamic>,
            )
          : null,
      repliedTo: json['replied_to'] != null
          ? RepliedToModel.fromJson(
              json['replied_to'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  // Display text of this message
  String get displayText {
    if (isDeleted) return 'This message was unsent';
    if (messageType == 'like') return '❤️';
    return content ?? '';
  }

  // Is this a text message?
  bool get isText => messageType == 'text';

  // Is this a like reaction?
  bool get isLike => messageType == 'like';

  // Create a copy with modified fields
  MessageModel copyWith({
    bool? isSending,
    bool? hasError,
    bool? isDeleted,
  }) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      messageType: messageType,
      content: content,
      mediaUrl: mediaUrl,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt,
      createdAt: createdAt,
      sender: sender,
      repliedTo: repliedTo,
      isSending: isSending ?? this.isSending,
      hasError: hasError ?? this.hasError,
    );
  }
}

