// lib/features/share/models/share_target.dart

import 'package:flutter/material.dart';

enum ShareTargetType {
  user,           // Direct message to single user
  group,          // Existing group chat
  closeFriends,   // Close friends list
  notes,          // Add to your note
}

class ShareTarget {
  final String id;
  final String name;
  final String? username;       // for users
  final String? avatarUrl;
  final List<String>? memberAvatars; // for groups (up to 4)
  final ShareTargetType type;
  
  // States
  final bool isVerified;
  final bool isOnline;
  final bool hasStory;
  final bool hasSeenStory;
  final bool isCloseFriend;
  
  // Group info
  final int? memberCount;
  
  // Recent state
  final bool isRecent;          // Recently messaged
  final DateTime? lastMessageAt;

  const ShareTarget({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    this.memberAvatars,
    required this.type,
    this.isVerified = false,
    this.isOnline = false,
    this.hasStory = false,
    this.hasSeenStory = false,
    this.isCloseFriend = false,
    this.memberCount,
    this.isRecent = false,
    this.lastMessageAt,
  });

  String get displayName {
    if (type == ShareTargetType.user) {
      return username ?? name;
    }
    return name;
  }

  String get subtitle {
    switch (type) {
      case ShareTargetType.user:
        return name;
      case ShareTargetType.group:
        return '${memberCount ?? 0} members';
      case ShareTargetType.closeFriends:
        return 'Close friends';
      case ShareTargetType.notes:
        return 'Note';
    }
  }
}
