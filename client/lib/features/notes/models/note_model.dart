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

  // New properties for Music & GIF
  final String noteType;

  // Music Share
  final String? musicTrackId;
  final String? musicTrackName;
  final String? musicArtistName;
  final String? musicAlbumArt;
  final String? musicPreviewUrl;
  final int? musicDuration;
  final String? musicPlatform;

  // GIF Share
  final String? gifId;
  final String? gifUrl;
  final String? gifPreviewUrl;
  final String? gifTitle;
  final int? gifWidth;
  final int? gifHeight;
  final String? gifSource;

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
    this.noteType = 'text',
    this.musicTrackId,
    this.musicTrackName,
    this.musicArtistName,
    this.musicAlbumArt,
    this.musicPreviewUrl,
    this.musicDuration,
    this.musicPlatform = 'spotify',
    this.gifId,
    this.gifUrl,
    this.gifPreviewUrl,
    this.gifTitle,
    this.gifWidth,
    this.gifHeight,
    this.gifSource = 'giphy',
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
    String? noteType,
    String? musicTrackId,
    String? musicTrackName,
    String? musicArtistName,
    String? musicAlbumArt,
    String? musicPreviewUrl,
    int? musicDuration,
    String? musicPlatform,
    String? gifId,
    String? gifUrl,
    String? gifPreviewUrl,
    String? gifTitle,
    int? gifWidth,
    int? gifHeight,
    String? gifSource,
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
      noteType: noteType ?? this.noteType,
      musicTrackId: musicTrackId ?? this.musicTrackId,
      musicTrackName: musicTrackName ?? this.musicTrackName,
      musicArtistName: musicArtistName ?? this.musicArtistName,
      musicAlbumArt: musicAlbumArt ?? this.musicAlbumArt,
      musicPreviewUrl: musicPreviewUrl ?? this.musicPreviewUrl,
      musicDuration: musicDuration ?? this.musicDuration,
      musicPlatform: musicPlatform ?? this.musicPlatform,
      gifId: gifId ?? this.gifId,
      gifUrl: gifUrl ?? this.gifUrl,
      gifPreviewUrl: gifPreviewUrl ?? this.gifPreviewUrl,
      gifTitle: gifTitle ?? this.gifTitle,
      gifWidth: gifWidth ?? this.gifWidth,
      gifHeight: gifHeight ?? this.gifHeight,
      gifSource: gifSource ?? this.gifSource,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'audience': audience.index,
      'isOwn': isOwn,
      'replyCount': replyCount,
      'noteType': noteType,
      'musicTrackId': musicTrackId,
      'musicTrackName': musicTrackName,
      'musicArtistName': musicArtistName,
      'musicAlbumArt': musicAlbumArt,
      'musicPreviewUrl': musicPreviewUrl,
      'musicDuration': musicDuration,
      'musicPlatform': musicPlatform,
      'gifId': gifId,
      'gifUrl': gifUrl,
      'gifPreviewUrl': gifPreviewUrl,
      'gifTitle': gifTitle,
      'gifWidth': gifWidth,
      'gifHeight': gifHeight,
      'gifSource': gifSource,
    };
  }

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    NoteAudience resolvedAudience = NoteAudience.followers;
    if (json['audience'] != null) {
      if (json['audience'] is int) {
        resolvedAudience = NoteAudience.values[json['audience'] as int];
      } else if (json['audience'] == 'close_friends' || json['audience'] == 1) {
        resolvedAudience = NoteAudience.closeFriends;
      }
    }

    return NoteModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : json['created_at'] != null 
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
      audience: resolvedAudience,
      isOwn: json['isOwn'] as bool? ?? json['is_own'] as bool? ?? false,
      replyCount: json['replyCount'] as int? ?? json['reply_count'] as int? ?? 0,
      noteType: json['noteType'] as String? ?? json['note_type'] as String? ?? 'text',
      musicTrackId: json['musicTrackId'] as String? ?? json['music_track_id'] as String?,
      musicTrackName: json['musicTrackName'] as String? ?? json['music_track_name'] as String?,
      musicArtistName: json['musicArtistName'] as String? ?? json['music_artist_name'] as String?,
      musicAlbumArt: json['musicAlbumArt'] as String? ?? json['music_album_art'] as String?,
      musicPreviewUrl: json['musicPreviewUrl'] as String? ?? json['music_preview_url'] as String?,
      musicDuration: json['musicDuration'] as int? ?? json['music_duration'] as int?,
      musicPlatform: json['musicPlatform'] as String? ?? json['music_platform'] as String? ?? 'spotify',
      gifId: json['gifId'] as String? ?? json['gif_id'] as String?,
      gifUrl: json['gifUrl'] as String? ?? json['gif_url'] as String?,
      gifPreviewUrl: json['gifPreviewUrl'] as String? ?? json['gif_preview_url'] as String?,
      gifTitle: json['gifTitle'] as String? ?? json['gif_title'] as String?,
      gifWidth: json['gifWidth'] as int? ?? json['gif_width'] as int?,
      gifHeight: json['gifHeight'] as int? ?? json['gif_height'] as int?,
      gifSource: json['gifSource'] as String? ?? json['gif_source'] as String? ?? 'giphy',
    );
  }
}
