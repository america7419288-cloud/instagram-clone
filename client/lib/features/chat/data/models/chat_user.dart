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

  // Non-Hive fields
  final String role;
  final DateTime? lastReadAt;

  ChatUser({
    required this.id,
    required this.username,
    this.fullName,
    this.profilePicUrl,
    this.isVerified = false,
    this.role = 'member',
    this.lastReadAt,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? json['fullName'],
      profilePicUrl: json['profile_pic_url'] ?? json['profilePicUrl'],
      isVerified: json['is_verified'] ?? json['isVerified'] ?? false,
      role: json['role'] ?? 'member',
      lastReadAt: json['last_read_at'] != null 
          ? DateTime.tryParse(json['last_read_at'].toString()) 
          : json['lastReadAt'] != null 
              ? DateTime.tryParse(json['lastReadAt'].toString()) 
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'profile_pic_url': profilePicUrl,
      'is_verified': isVerified,
      'role': role,
      'last_read_at': lastReadAt?.toIso8601String(),
    };
  }
}
