// lib/features/notes/models/note_model.dart

enum NoteAudience { followers, closeFriends }

class NoteModel {
  final String id;
  final String userId;
  final String username;
  final String avatarUrl;
  final String text;
  final DateTime createdAt;
  final DateTime expiresAt;
  final NoteAudience audience;
  final bool isOwn;
  final int replyCount;

  NoteModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.text,
    required this.createdAt,
    required this.audience,
    this.isOwn = false,
    this.replyCount = 0,
  }) : expiresAt = createdAt.add(const Duration(hours: 24));

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  double get opacityLevel {
    final hoursRemaining = timeRemaining.inHours;
    if (hoursRemaining > 12) return 1.0;
    if (hoursRemaining > 4)  return 0.85;
    if (hoursRemaining > 1)  return 0.65;
    return 0.4;
  }

  bool get isExpiringSoon => timeRemaining.inHours < 1;

  String get timeRemainingText {
    final h = timeRemaining.inHours;
    final m = timeRemaining.inMinutes % 60;
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String get postedAgoText {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool get isEmojiOnly {
    // Check if text contains only emoji characters
    final emojiRegex = RegExp(
      r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}'
      r'\u{2700}-\u{27BF}\u{1F000}-\u{1F02F}'
      r'\u{1F0A0}-\u{1F0FF}\u{FE00}-\u{FE0F}'
      r'\u{1F900}-\u{1F9FF}\s]+$',
      unicode: true,
    );
    return emojiRegex.hasMatch(text.trim());
  }

  NoteModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? avatarUrl,
    String? text,
    DateTime? createdAt,
    NoteAudience? audience,
    bool? isOwn,
    int? replyCount,
  }) {
    return NoteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      audience: audience ?? this.audience,
      isOwn: isOwn ?? this.isOwn,
      replyCount: replyCount ?? this.replyCount,
    );
  }
}
