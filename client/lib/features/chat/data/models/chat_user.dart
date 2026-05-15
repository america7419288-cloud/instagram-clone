import 'package:hive_ce/hive.dart';

part 'chat_user.g.dart';

@HiveType(typeId: 0)
class ChatUser {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String username;
  
  @HiveField(2)
  final String? fullName;
  
  @HiveField(3)
  final String? profilePicUrl;
  
  @HiveField(4)
  final bool isVerified;

  ChatUser({
    required this.id,
    required this.username,
    this.fullName,
    this.profilePicUrl,
    this.isVerified = false,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      fullName: json['full_name'],
      profilePicUrl: json['profile_pic_url'],
      isVerified: json['is_verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'profile_pic_url': profilePicUrl,
      'is_verified': isVerified,
    };
  }
}
