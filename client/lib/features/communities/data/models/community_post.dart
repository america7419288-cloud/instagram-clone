import '../../../chat/data/models/chat_user.dart';

class CommunityPost {
  final String id;
  final String communityId;
  final String channelId;
  final String authorId;
  final String content;
  final List<Map<String, dynamic>> mediaUrls; // [{'url': '...', 'type': 'image'|'video'}]
  final String type; // 'text' | 'media' | 'poll' | 'event'
  final Map<String, dynamic>? poll; // {'question': '...', 'options': [{'text': '...', 'votes': ['userId']}], 'endsAt': '...'}
  final Map<String, dynamic>? event; // {'title': '...', 'description': '...', 'startDate': '...', 'endDate': '...', 'location': '...', 'coverUrl': '...', 'attendees': ['userId']}
  final List<String> likes; // userIds
  final int commentCount;
  final int likeCount;
  final bool isPinned;
  final bool isAnnouncement;
  final String status; // 'pending' | 'published' | 'hidden'
  final ChatUser? author;
  final DateTime createdAt;

  CommunityPost({
    required this.id,
    required this.communityId,
    required this.channelId,
    required this.authorId,
    required this.content,
    required this.mediaUrls,
    required this.type,
    this.poll,
    this.event,
    required this.likes,
    required this.commentCount,
    required this.likeCount,
    required this.isPinned,
    required this.isAnnouncement,
    required this.status,
    this.author,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] ?? '',
      communityId: json['community_id'] ?? '',
      channelId: json['channel_id'] ?? '',
      authorId: json['author_id'] ?? '',
      content: json['content'] ?? '',
      mediaUrls: json['media_urls'] != null ? List<Map<String, dynamic>>.from(
        (json['media_urls'] as List).map((x) => Map<String, dynamic>.from(x))
      ) : const [],
      type: json['type'] ?? 'text',
      poll: json['poll'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['poll']) : null,
      event: json['event'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['event']) : null,
      likes: json['likes'] != null ? List<String>.from(json['likes']) : const [],
      commentCount: json['comment_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      isPinned: json['is_pinned'] ?? false,
      isAnnouncement: json['is_announcement'] ?? false,
      status: json['status'] ?? 'published',
      author: json['author'] != null ? ChatUser.fromJson(json['author']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'community_id': communityId,
      'channel_id': channelId,
      'author_id': authorId,
      'content': content,
      'media_urls': mediaUrls,
      'type': type,
      'poll': poll,
      'event': event,
      'likes': likes,
      'comment_count': commentCount,
      'like_count': likeCount,
      'is_pinned': isPinned,
      'is_announcement': isAnnouncement,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
