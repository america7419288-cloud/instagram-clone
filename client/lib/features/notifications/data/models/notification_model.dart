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
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['fullName']?.toString(),
      profilePicUrl: json['profile_pic_url']?.toString() ?? json['profilePicUrl']?.toString(),
      isVerified: json['is_verified'] == true ||
          json['is_verified'] == 1 ||
          json['is_verified']?.toString() == 'true' ||
          json['isVerified'] == true ||
          json['isVerified'] == 1 ||
          json['isVerified']?.toString() == 'true',
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
  final String? referenceReelId;

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
    this.referenceReelId,
    this.postThumbnail,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    DateTime? parsedCreatedAt;
    if (rawCreatedAt != null) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt.toString());
      // Fallback for millisecond epoch integers
      if (parsedCreatedAt == null && (rawCreatedAt is int || int.tryParse(rawCreatedAt.toString()) != null)) {
        final ms = int.tryParse(rawCreatedAt.toString());
        if (ms != null) {
          parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(ms);
        }
      }
    }

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isRead: json['is_read'] == true ||
          json['is_read'] == 1 ||
          json['is_read']?.toString() == 'true' ||
          json['isRead'] == true ||
          json['isRead'] == 1 ||
          json['isRead']?.toString() == 'true',
      createdAt: parsedCreatedAt,
      sender: json['sender'] != null
          ? NotificationSenderModel.fromJson(json['sender'])
          : null,
      referencePostId: json['reference_post_id']?.toString() ?? json['referencePostId']?.toString(),
      referenceCommentId: json['reference_comment_id']?.toString() ?? json['referenceCommentId']?.toString(),
      referenceStoryId: json['reference_story_id']?.toString() ?? json['referenceStoryId']?.toString(),
      referenceReelId: json['reference_reel_id']?.toString() ?? json['referenceReelId']?.toString() ?? json['reference_reel']?.toString(),
      postThumbnail: json['post_thumbnail']?.toString() ?? json['postThumbnail']?.toString(),
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
      referenceReelId: referenceReelId,
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
  bool get isReelLike => type == 'reel_like';
  bool get isReelComment => type == 'reel_comment';

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
