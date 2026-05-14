// lib/features/share/models/share_content.dart

import 'package:flutter/material.dart';

enum ShareContentType {
  post,
  reel,
  story,
  profile,
}

class ShareContent {
  final String id;
  final ShareContentType type;
  final String? thumbnailUrl;
  final String? authorUsername;
  final String? authorAvatarUrl;
  final String? caption;

  const ShareContent({
    required this.id,
    required this.type,
    this.thumbnailUrl,
    this.authorUsername,
    this.authorAvatarUrl,
    this.caption,
  });
}

// External share options
enum ShareExternalOption {
  addToStory,
  addToReels,
  shareToFacebook,
  shareToWhatsApp,
  shareToMessages,
  copyLink,
  shareTo,        // System share sheet
  qrCode,
  saveToDevice,
  remix,
  notInterested,
  report,
}

class ExternalShareOption {
  final ShareExternalOption type;
  final String label;
  final IconData icon;
  final Color? iconColor;
  final bool isDestructive;

  const ExternalShareOption({
    required this.type,
    required this.label,
    required this.icon,
    this.iconColor,
    this.isDestructive = false,
  });
}
