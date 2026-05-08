class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? duration;
  final String? thumbnail;
  final Duration startTime;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.thumbnail,
    this.startTime = Duration.zero,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      album: json['album'],
      duration: json['duration'],
      thumbnail: json['thumbnail'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'thumbnail': thumbnail,
      'startTime': startTime.inSeconds,
    };
  }

  MusicTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? duration,
    String? thumbnail,
    Duration? startTime,
  }) {
    return MusicTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      thumbnail: thumbnail ?? this.thumbnail,
      startTime: startTime ?? this.startTime,
    );
  }
}
