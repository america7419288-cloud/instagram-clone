// lib/features/menu/models/menu_action.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum MenuActionType {
  // Common
  share,
  copyLink,
  qrCode,
  
  // Post / Reel actions
  saveCollection,
  unsave,
  notInterested,
  whyYouSeeing,
  
  // Following actions
  unfollow,
  follow,
  mute,
  restrict,
  block,
  
  // Privacy
  hide,
  hideAllFromUser,
  
  // Owner actions
  edit,
  archive,
  delete,
  pin,
  unpin,
  hideLikeCount,
  turnOffComments,
  turnOnComments,
  editAudience,
  insights,
  boost,
  shareToReels,
  shareToFeed,
  shareToStory,
  
  // Story specific
  saveStory,
  saveAllStory,
  highlightStory,
  storySettings,
  
  // Reel specific
  remix,
  saveAudio,
  
  // Reporting
  report,
  
  // Accessibility
  altText,
  
  // Other
  about,
  manage,
  notifications,
  download,
  embed,
  translation,
  closeFriendsOnly,
  save,
}

enum MenuActionStyle {
  normal,        // Black text
  destructive,   // Red text
  primary,       // Blue text
}

class MenuAction {
  final MenuActionType type;
  final String label;
  final String? subtitle;
  final IconData icon;
  final MenuActionStyle style;
  final bool showChevron;
  final Widget? trailing;
  final bool requiresConfirmation;

  const MenuAction({
    required this.type,
    required this.label,
    this.subtitle,
    required this.icon,
    this.style = MenuActionStyle.normal,
    this.showChevron = false,
    this.trailing,
    this.requiresConfirmation = false,
  });
}

class MenuSection {
  final String? title;
  final List<MenuAction> actions;
  final bool showDivider;

  const MenuSection({
    this.title,
    required this.actions,
    this.showDivider = true,
  });
}
