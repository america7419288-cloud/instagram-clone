// lib/features/notifications/data/models/notification_model.dart

class NotificationSenderModel {
  final String id;
  final String username;
  final String? fullName;
  final String? profilePicUrl;
  final bool isVerified;

  const NotificationSenderModel({
    required this.id,
    required this.username,
    this.fullName,
    this.profilePicUrl,
    required this.isVerified,
  });

  factory NotificationSenderModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return NotificationSenderModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      fullName: json['full_name'],
      profilePicUrl: json['profile_pic_url'],
      isVerified: json['is_verified'] ?? false,
    );
  }
}

class NotificationModel {
  final String id;
  final String type;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  // Who sent the notification
  final NotificationSenderModel? sender;

  // References (for navigation on tap)
  final String? referencePostId;
  final String? referenceCommentId;
  final String? referenceStoryId;

  // Post thumbnail (right side image)
  final String? postThumbnail;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    this.createdAt,
    this.sender,
    this.referencePostId,
    this.referenceCommentId,
    this.referenceStoryId,
    this.postThumbnail,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      sender: json['sender'] != null
          ? NotificationSenderModel.fromJson(json['sender'])
          : null,
      referencePostId: json['reference_post_id'],
      referenceCommentId: json['reference_comment_id'],
      referenceStoryId: json['reference_story_id'],
      postThumbnail: json['post_thumbnail'],
    );
  }

  // Create a copy with isRead = true
  NotificationModel markAsRead() {
    return NotificationModel(
      id: id,
      type: type,
      message: message,
      isRead: true,
      createdAt: createdAt,
      sender: sender,
      referencePostId: referencePostId,
      referenceCommentId: referenceCommentId,
      referenceStoryId: referenceStoryId,
      postThumbnail: postThumbnail,
    );
  }

  // ─── TYPE HELPERS ─────────────────────────────────────────
  bool get isLike => type == 'like';
  bool get isComment => type == 'comment';
  bool get isReply => type == 'reply';
  bool get isFollow => type == 'follow';
  bool get isFollowRequest => type == 'follow_request';
  bool get isFollowAccept => type == 'follow_accept';
  bool get isMention =>
      type == 'mention_post' || type == 'mention_comment';
  bool get isCommentLike => type == 'comment_like';

  // Does this notification have a post reference?
  bool get hasPostReference => referencePostId != null;

  // Does this notification show a Follow button?
  bool get showFollowButton =>
      type == 'follow' || type == 'follow_request';
}

// ─── GROUPED NOTIFICATIONS ──────────────────────────────────
// For displaying in sections
class NotificationGroup {
  final String title;          // "This Week", "This Month", etc.
  final List<NotificationModel> notifications;

  const NotificationGroup({
    required this.title,
    required this.notifications,
  });
}