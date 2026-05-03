// lib/features/reels/data/models/reel_model.dart

class ReelModel {
  final String id;
  final String userId;
  final String username;
  final String? fullName;
  final String? userAvatar;
  final bool isVerified;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? caption;
  final String? audioName;
  final int duration;
  final int likesCount;
  final int commentsCount;
  final int playsCount;
  final bool isLiked;
  final bool isFollowing;
  final bool isOwnReel;
  final DateTime createdAt;

  const ReelModel({
    required this.id,
    required this.userId,
    required this.username,
    this.fullName,
    this.userAvatar,
    this.isVerified = false,
    required this.videoUrl,
    this.thumbnailUrl,
    this.caption,
    this.audioName,
    this.duration = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.playsCount = 0,
    this.isLiked = false,
    this.isFollowing = false,
    this.isOwnReel = false,
    required this.createdAt,
  });

  // ─── Duration formatted ────────────────────────────────
  String get durationFormatted {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString(),
      userAvatar: json['userAvatar']?.toString(),
      isVerified: json['isVerified'] == true,
      videoUrl: json['videoUrl']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      caption: json['caption']?.toString(),
      audioName: json['audioName']?.toString(),
      duration: int.tryParse(
            json['duration']?.toString() ?? '0',
          ) ??
          0,
      likesCount: int.tryParse(
            json['likesCount']?.toString() ?? '0',
          ) ??
          0,
      commentsCount: int.tryParse(
            json['commentsCount']?.toString() ?? '0',
          ) ??
          0,
      playsCount: int.tryParse(
            json['playsCount']?.toString() ?? '0',
          ) ??
          0,
      isLiked: json['isLiked'] == true,
      isFollowing: json['isFollowing'] == true,
      isOwnReel: json['isOwnReel'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  ReelModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? fullName,
    String? userAvatar,
    bool? isVerified,
    String? videoUrl,
    String? thumbnailUrl,
    String? caption,
    String? audioName,
    int? duration,
    int? likesCount,
    int? commentsCount,
    int? playsCount,
    bool? isLiked,
    bool? isFollowing,
    bool? isOwnReel,
    DateTime? createdAt,
  }) {
    return ReelModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      userAvatar: userAvatar ?? this.userAvatar,
      isVerified: isVerified ?? this.isVerified,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      caption: caption ?? this.caption,
      audioName: audioName ?? this.audioName,
      duration: duration ?? this.duration,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      playsCount: playsCount ?? this.playsCount,
      isLiked: isLiked ?? this.isLiked,
      isFollowing: isFollowing ?? this.isFollowing,
      isOwnReel: isOwnReel ?? this.isOwnReel,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}