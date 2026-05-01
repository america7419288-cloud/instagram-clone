// lib/features/post/data/models/comment_model.dart

class CommentUserModel {
  final String id;
  final String username;
  final String? profilePicUrl;
  final bool isVerified;

  const CommentUserModel({
    required this.id,
    required this.username,
    this.profilePicUrl,
    required this.isVerified,
  });

  factory CommentUserModel.fromJson(Map<String, dynamic> json) {
    return CommentUserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      profilePicUrl: json['profile_pic_url'],
      isVerified: json['is_verified'] ?? false,
    );
  }
}

class CommentModel {
  final String id;
  final String content;
  final CommentUserModel? user;
  final String postId;
  final String? parentCommentId;
  final bool isPinned;
  final int likeCount;
  final int replyCount;
  final bool isLiked;
  final bool isOwnComment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Local-only: tracks if replies are expanded
  final bool repliesExpanded;

  const CommentModel({
    required this.id,
    required this.content,
    this.user,
    required this.postId,
    this.parentCommentId,
    required this.isPinned,
    required this.likeCount,
    required this.replyCount,
    required this.isLiked,
    required this.isOwnComment,
    this.createdAt,
    this.updatedAt,
    this.repliesExpanded = false,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      user: json['user'] != null
          ? CommentUserModel.fromJson(json['user'])
          : null,
      postId: json['post_id'] ?? '',
      parentCommentId: json['parent_comment_id'],
      isPinned: json['is_pinned'] ?? false,
      likeCount: json['like_count'] ?? 0,
      replyCount: json['reply_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isOwnComment: json['is_own_comment'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  CommentModel copyWith({
    int? likeCount,
    bool? isLiked,
    int? replyCount,
    bool? repliesExpanded,
    bool? isPinned,
  }) {
    return CommentModel(
      id: id,
      content: content,
      user: user,
      postId: postId,
      parentCommentId: parentCommentId,
      isPinned: isPinned ?? this.isPinned,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      isLiked: isLiked ?? this.isLiked,
      isOwnComment: isOwnComment,
      createdAt: createdAt,
      updatedAt: updatedAt,
      repliesExpanded: repliesExpanded ?? this.repliesExpanded,
    );
  }

  bool get isReply => parentCommentId != null;
}