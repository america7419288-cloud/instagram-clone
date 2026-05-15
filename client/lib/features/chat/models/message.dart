import 'package:flutter/material.dart';

// ── Enums ──────────────────────────────────

enum MessageType {
  text,
  image,
  video,
  audio,
  reel,
  post,
  storyReply,
  gif,
  reaction,
  deleted,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  seen,
  failed,
}

// ── Sub-models ─────────────────────────────

class AudioData {
  final Duration duration;
  final List<double> waveform; // 0.0 → 1.0 values

  const AudioData({
    required this.duration,
    required this.waveform,
  });

  // Generate mock waveform
  factory AudioData.mock(Duration duration) {
    final bars = List.generate(
      40,
      (i) => (((i * 7 + 3) % 9) / 9.0)
          .clamp(0.15, 1.0),
    );
    return AudioData(duration: duration, waveform: bars);
  }
}

class MessageReaction {
  final String userId;
  final String username;
  final String emoji;
  final DateTime at;

  const MessageReaction({
    required this.userId,
    required this.username,
    required this.emoji,
    required this.at,
  });
}

class ReplyData {
  final String messageId;
  final String senderId;
  final String senderName;
  final String previewText;
  final String? previewImage;
  final MessageType originalType;

  const ReplyData({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.previewText,
    this.previewImage,
    required this.originalType,
  });
}

// ── Main Model ─────────────────────────────

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;

  // Content
  final MessageType type;
  final String? text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final double? aspectRatio;
  final AudioData? audioData;

  // Shared content metadata
  final String? sharedUsername;
  final String? sharedCaption;
  final String? sharedPostId;
  final String? sharedThumbnailUrl;

  // State
  final DateTime timestamp;
  final MessageStatus status;
  final bool isFromMe;
  final bool isDeleted;
  final bool isDisappearing;
  final bool disappearingViewed;
  final bool isForwarded;

  // Threads
  final ReplyData? replyTo;
  final List<MessageReaction> reactions;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.type,
    this.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.aspectRatio,
    this.audioData,
    this.sharedUsername,
    this.sharedCaption,
    this.sharedPostId,
    this.sharedThumbnailUrl,
    required this.timestamp,
    required this.status,
    required this.isFromMe,
    this.isDeleted = false,
    this.isDisappearing = false,
    this.disappearingViewed = false,
    this.isForwarded = false,
    this.replyTo,
    this.reactions = const [],
  });

  // ── Helpers ─────────────────────────────

  bool get isEmojiOnly {
    if (type != MessageType.text || text == null) {
      return false;
    }
    final trimmed = text!.trim();
    if (trimmed.isEmpty || trimmed.length > 12) {
      return false;
    }
    // Check if all characters are emoji
    final nonEmojiRegex = RegExp(r'[a-zA-Z0-9\s]');
    return !nonEmojiRegex.hasMatch(trimmed);
  }

  bool get isViewed => disappearingViewed;
  String? get audioDuration => audioData?.duration.toString().split('.').first.padLeft(8, '0').substring(3);
  String? get videoDuration => '0:15'; // Placeholder or add field later

  String get timeDisplay {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${timestamp.month}/${timestamp.day}';
  }

  String get previewText {
    if (isDeleted) {
      return isFromMe
          ? 'You unsent a message'
          : 'Message unsent';
    }
    switch (type) {
      case MessageType.text:
        return text ?? '';
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎤 Voice message';
      case MessageType.reel:
        return '🎬 Reel';
      case MessageType.post:
        return '📸 Post';
      case MessageType.gif:
        return 'GIF';
      default:
        return text ?? '';
    }
  }

  ChatMessage copyWith({
    MessageStatus? status,
    bool? isDeleted,
    List<MessageReaction>? reactions,
    bool? disappearingViewed,
  }) =>
      ChatMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        type: type,
        text: text,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        aspectRatio: aspectRatio,
        audioData: audioData,
        sharedUsername: sharedUsername,
        sharedCaption: sharedCaption,
        sharedPostId: sharedPostId,
        sharedThumbnailUrl: sharedThumbnailUrl,
        timestamp: timestamp,
        status: status ?? this.status,
        isFromMe: isFromMe,
        isDeleted: isDeleted ?? this.isDeleted,
        isDisappearing: isDisappearing,
        disappearingViewed:
            disappearingViewed ?? this.disappearingViewed,
        isForwarded: isForwarded,
        replyTo: replyTo,
        reactions: reactions ?? this.reactions,
      );

  // ── Mock Data ────────────────────────────

  static List<ChatMessage> mockMessages() {
    final now = DateTime.now();
    return [
      // Oldest messages at end of list
      // (list is reversed in ListView)
      ChatMessage(
        id: '1',
        conversationId: 'conv1',
        senderId: 'other',
        senderName: 'johndoe',
        senderAvatar: 'https://i.pravatar.cc/150?img=1',
        type: MessageType.text,
        text: 'Hey! How are you doing? 👋',
        timestamp: now.subtract(
            const Duration(hours: 3, minutes: 20)),
        status: MessageStatus.seen,
        isFromMe: false,
      ),
      ChatMessage(
        id: '2',
        conversationId: 'conv1',
        senderId: 'me',
        senderName: 'me',
        type: MessageType.text,
        text: 'Hey! I\'m doing great, thanks for asking',
        timestamp: now.subtract(
            const Duration(hours: 3, minutes: 18)),
        status: MessageStatus.seen,
        isFromMe: true,
      ),
      ChatMessage(
        id: '3',
        conversationId: 'conv1',
        senderId: 'me',
        senderName: 'me',
        type: MessageType.text,
        text: 'Just working on a new project',
        timestamp: now.subtract(
            const Duration(hours: 3, minutes: 17)),
        status: MessageStatus.seen,
        isFromMe: true,
      ),
      ChatMessage(
        id: '4',
        conversationId: 'conv1',
        senderId: 'other',
        senderName: 'johndoe',
        senderAvatar: 'https://i.pravatar.cc/150?img=1',
        type: MessageType.text,
        text: 'That sounds awesome! 🔥',
        timestamp: now.subtract(
            const Duration(hours: 3, minutes: 10)),
        status: MessageStatus.seen,
        isFromMe: false,
        reactions: [
          MessageReaction(
            userId: 'me',
            username: 'me',
            emoji: '❤️',
            at: now.subtract(const Duration(hours: 3)),
          ),
        ],
      ),
      ChatMessage(
        id: '5',
        conversationId: 'conv1',
        senderId: 'other',
        senderName: 'johndoe',
        senderAvatar: 'https://i.pravatar.cc/150?img=1',
        type: MessageType.text,
        text: 'What\'s it about?',
        timestamp: now.subtract(
            const Duration(hours: 3, minutes: 9)),
        status: MessageStatus.seen,
        isFromMe: false,
      ),
      ChatMessage(
        id: '6',
        conversationId: 'conv1',
        senderId: 'me',
        senderName: 'me',
        type: MessageType.image,
        mediaUrl: 'https://picsum.photos/400/500',
        thumbnailUrl: 'https://picsum.photos/400/500',
        aspectRatio: 4 / 5,
        timestamp: now.subtract(
            const Duration(hours: 2, minutes: 45)),
        status: MessageStatus.seen,
        isFromMe: true,
      ),
      ChatMessage(
        id: '7',
        conversationId: 'conv1',
        senderId: 'me',
        senderName: 'me',
        type: MessageType.text,
        text: 'Working on a Flutter app with a custom chat UI',
        timestamp: now.subtract(
            const Duration(hours: 2, minutes: 44)),
        status: MessageStatus.seen,
        isFromMe: true,
      ),
      ChatMessage(
        id: '8',
        conversationId: 'conv1',
        senderId: 'other',
        senderName: 'johndoe',
        senderAvatar: 'https://i.pravatar.cc/150?img=1',
        type: MessageType.audio,
        audioData: AudioData.mock(
            const Duration(seconds: 14)),
        timestamp: now.subtract(
            const Duration(hours: 1, minutes: 30)),
        status: MessageStatus.seen,
        isFromMe: false,
      ),
      ChatMessage(
        id: '9',
        conversationId: 'conv1',
        senderId: 'me',
        senderName: 'me',
        type: MessageType.text,
        text: '😂😂',
        timestamp: now.subtract(
            const Duration(hours: 1, minutes: 20)),
        status: MessageStatus.seen,
        isFromMe: true,
      ),
      ChatMessage(
        id: '10',
        conversationId: 'conv1',
        senderId: 'other',
        senderName: 'johndoe',
        senderAvatar: 'https://i.pravatar.cc/150?img=1',
        type: MessageType.text,
        text: 'Looks really clean! Love the design 😍',
        timestamp: now.subtract(
            const Duration(minutes: 30)),
        status: MessageStatus.seen,
        isFromMe: false,
      ),
      ChatMessage(
        id: '11',
        conversationId: 'conv1',
        senderId: 'me',
        senderName: 'me',
        type: MessageType.text,
        text: 'Thanks! Still working on some animations',
        timestamp: now.subtract(
            const Duration(minutes: 25)),
        status: MessageStatus.seen,
        isFromMe: true,
        replyTo: const ReplyData(
          messageId: '10',
          senderId: 'other',
          senderName: 'johndoe',
          previewText: 'Looks really clean! Love the design 😍',
          originalType: MessageType.text,
        ),
      ),
      ChatMessage(
        id: '12',
        conversationId: 'conv1',
        senderId: 'other',
        senderName: 'johndoe',
        senderAvatar: 'https://i.pravatar.cc/150?img=1',
        type: MessageType.text,
        text: 'I bet it\'ll be amazing when done!',
        timestamp:
            now.subtract(const Duration(minutes: 10)),
        status: MessageStatus.seen,
        isFromMe: false,
      ),
      ChatMessage(
        id: '13',
        conversationId: 'conv1',
        senderId: 'me',
        senderName: 'me',
        type: MessageType.text,
        text: 'Will share it soon 🚀',
        timestamp:
            now.subtract(const Duration(minutes: 2)),
        status: MessageStatus.delivered,
        isFromMe: true,
      ),
    ];
  }
}
