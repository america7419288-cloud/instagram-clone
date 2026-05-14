// lib/features/menu/controllers/menu_controller.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/menu_action.dart';
import '../models/menu_context.dart';

class MenuActionResolver {
  
  // Returns the menu sections for a given content context
  static List<MenuSection> getSections(MenuContext ctx) {
    switch (ctx.contentType) {
      case MenuContentType.post:
        return _postSections(ctx);
      case MenuContentType.reel:
        return _reelSections(ctx);
      case MenuContentType.story:
        return _storySections(ctx);
      case MenuContentType.comment:
        return _commentSections(ctx);
      case MenuContentType.profile:
        return _profileSections(ctx);
      case MenuContentType.message:
        return _messageSections(ctx);
    }
  }

  // ── POST MENU ──────────────────────────────
  
  static List<MenuSection> _postSections(MenuContext ctx) {
    if (ctx.isOwner) {
      return [
        MenuSection(actions: [
          MenuAction(
            type: ctx.isPinned
                ? MenuActionType.unpin
                : MenuActionType.pin,
            label: ctx.isPinned
                ? 'Unpin from profile'
                : 'Pin to your profile',
            icon: ctx.isPinned
                ? LucideIcons.pinOff
                : LucideIcons.pin,
          ),
          const MenuAction(
            type: MenuActionType.archive,
            label: 'Archive',
            icon: LucideIcons.archive,
          ),
        ]),
        MenuSection(actions: [
          const MenuAction(
            type: MenuActionType.edit,
            label: 'Edit',
            icon: LucideIcons.pencil,
          ),
          MenuAction(
            type: ctx.hasLikeCount
                ? MenuActionType.hideLikeCount
                : MenuActionType.hideLikeCount,
            label: ctx.hasLikeCount
                ? 'Hide like count to others'
                : 'Show like count to others',
            icon: ctx.hasLikeCount
                ? LucideIcons.eyeOff
                : LucideIcons.eye,
          ),
          MenuAction(
            type: ctx.commentsEnabled
                ? MenuActionType.turnOffComments
                : MenuActionType.turnOnComments,
            label: ctx.commentsEnabled
                ? 'Turn off commenting'
                : 'Turn on commenting',
            icon: ctx.commentsEnabled
                ? LucideIcons.messageCircle
                : LucideIcons.messageCircle,
          ),
        ]),
        MenuSection(actions: [
          const MenuAction(
            type: MenuActionType.editAudience,
            label: 'Edit audience',
            icon: LucideIcons.users,
          ),
          const MenuAction(
            type: MenuActionType.insights,
            label: 'View insights',
            icon: LucideIcons.barChart3,
          ),
          const MenuAction(
            type: MenuActionType.boost,
            label: 'Boost post',
            icon: LucideIcons.zap,
          ),
        ]),
        const MenuSection(actions: [
          MenuAction(
            type: MenuActionType.delete,
            label: 'Delete',
            icon: LucideIcons.trash2,
            style: MenuActionStyle.destructive,
            requiresConfirmation: true,
          ),
        ]),
      ];
    }

    // Other user's post
    return [
      MenuSection(actions: [
        MenuAction(
          type: ctx.isSaved
              ? MenuActionType.unsave
              : MenuActionType.saveCollection,
          label: ctx.isSaved ? 'Unsave' : 'Save',
          icon: ctx.isSaved
              ? LucideIcons.bookmark
              : LucideIcons.bookmark,
        ),
        const MenuAction(
          type: MenuActionType.qrCode,
          label: 'QR code',
          icon: LucideIcons.qrCode,
        ),
      ]),
      const MenuSection(actions: [
        MenuAction(
          type: MenuActionType.notInterested,
          label: 'Not interested',
          icon: LucideIcons.eyeOff,
        ),
        MenuAction(
          type: MenuActionType.whyYouSeeing,
          label: 'Why you\'re seeing this post',
          icon: LucideIcons.helpCircle,
          showChevron: true,
        ),
      ]),
      MenuSection(actions: [
        if (ctx.isFollowing)
          MenuAction(
            type: MenuActionType.unfollow,
            label: 'Unfollow',
            icon: LucideIcons.userMinus,
            style: MenuActionStyle.destructive,
          ),
        const MenuAction(
          type: MenuActionType.about,
          label: 'About this account',
          icon: LucideIcons.info,
          showChevron: true,
        ),
        const MenuAction(
          type: MenuActionType.hide,
          label: 'Hide',
          icon: LucideIcons.minusCircle,
        ),
        const MenuAction(
          type: MenuActionType.report,
          label: 'Report',
          icon: LucideIcons.flag,
          style: MenuActionStyle.destructive,
        ),
      ]),
    ];
  }

  // ── REEL MENU ──────────────────────────────
  
  static List<MenuSection> _reelSections(MenuContext ctx) {
    if (ctx.isOwner) {
      return [
        const MenuSection(actions: [
          MenuAction(
            type: MenuActionType.shareToFeed,
            label: 'Share to Feed',
            icon: LucideIcons.layoutGrid,
          ),
          MenuAction(
            type: MenuActionType.shareToStory,
            label: 'Share to Story',
            icon: LucideIcons.plusCircle,
          ),
        ]),
        const MenuSection(actions: [
          MenuAction(
            type: MenuActionType.edit,
            label: 'Manage',
            icon: LucideIcons.settings,
            showChevron: true,
          ),
          MenuAction(
            type: MenuActionType.insights,
            label: 'View insights',
            icon: LucideIcons.barChart3,
          ),
          MenuAction(
            type: MenuActionType.download,
            label: 'Save video',
            icon: LucideIcons.download,
          ),
        ]),
        const MenuSection(actions: [
          MenuAction(
            type: MenuActionType.delete,
            label: 'Delete',
            icon: LucideIcons.trash2,
            style: MenuActionStyle.destructive,
            requiresConfirmation: true,
          ),
        ]),
      ];
    }

    // Other's reel
    return [
      MenuSection(actions: [
        MenuAction(
          type: ctx.isSaved
              ? MenuActionType.unsave
              : MenuActionType.saveCollection,
          label: ctx.isSaved ? 'Unsave' : 'Save',
          icon: LucideIcons.bookmark,
        ),
        if (ctx.canRemix)
          const MenuAction(
            type: MenuActionType.remix,
            label: 'Remix this reel',
            icon: LucideIcons.copy,
          ),
        const MenuAction(
          type: MenuActionType.qrCode,
          label: 'QR code',
          icon: LucideIcons.qrCode,
        ),
      ]),
      const MenuSection(actions: [
        MenuAction(
          type: MenuActionType.notInterested,
          label: 'Not interested',
          icon: LucideIcons.eyeOff,
        ),
        MenuAction(
          type: MenuActionType.whyYouSeeing,
          label: 'Why you\'re seeing this reel',
          icon: LucideIcons.helpCircle,
          showChevron: true,
        ),
      ]),
      MenuSection(actions: [
        if (ctx.isFollowing)
          const MenuAction(
            type: MenuActionType.unfollow,
            label: 'Unfollow',
            icon: LucideIcons.userMinus,
            style: MenuActionStyle.destructive,
          ),
        const MenuAction(
          type: MenuActionType.about,
          label: 'About this account',
          icon: LucideIcons.info,
          showChevron: true,
        ),
        const MenuAction(
          type: MenuActionType.report,
          label: 'Report',
          icon: LucideIcons.flag,
          style: MenuActionStyle.destructive,
        ),
      ]),
    ];
  }

  // ── STORY MENU ─────────────────────────────
  
  static List<MenuSection> _storySections(MenuContext ctx) {
    if (ctx.isOwner) {
      return [
        const MenuSection(actions: [
          MenuAction(
            type: MenuActionType.delete,
            label: 'Delete',
            icon: LucideIcons.trash2,
            style: MenuActionStyle.destructive,
            requiresConfirmation: true,
          ),
        ]),
        const MenuSection(actions: [
          MenuAction(
            type: MenuActionType.saveStory,
            label: 'Save photo',
            icon: LucideIcons.download,
          ),
          MenuAction(
            type: MenuActionType.saveAllStory,
            label: 'Save story',
            icon: LucideIcons.downloadCloud,
          ),
          MenuAction(
            type: MenuActionType.highlightStory,
            label: 'Highlight',
            icon: LucideIcons.star,
          ),
        ]),
        const MenuSection(actions: [
          MenuAction(
            type: MenuActionType.shareToFeed,
            label: 'Share as post',
            icon: LucideIcons.layoutGrid,
          ),
          MenuAction(
            type: MenuActionType.storySettings,
            label: 'Story settings',
            icon: LucideIcons.settings,
            showChevron: true,
          ),
        ]),
      ];
    }

    // Other's story
    return [
      const MenuSection(actions: [
        MenuAction(
          type: MenuActionType.mute,
          label: 'Mute',
          icon: LucideIcons.bellOff,
          showChevron: true,
        ),
        MenuAction(
          type: MenuActionType.hide,
          label: 'Hide',
          icon: LucideIcons.eyeOff,
        ),
      ]),
      const MenuSection(actions: [
        MenuAction(
          type: MenuActionType.about,
          label: 'About this account',
          icon: LucideIcons.info,
          showChevron: true,
        ),
        MenuAction(
          type: MenuActionType.report,
          label: 'Report',
          icon: LucideIcons.flag,
          style: MenuActionStyle.destructive,
        ),
      ]),
    ];
  }

  // ── COMMENT MENU ───────────────────────────
  
  static List<MenuSection> _commentSections(MenuContext ctx) {
    if (ctx.isOwner) {
      return [
        const MenuSection(actions: [
          MenuAction(
            type: MenuActionType.delete,
            label: 'Delete',
            icon: LucideIcons.trash2,
            style: MenuActionStyle.destructive,
          ),
          MenuAction(
            type: MenuActionType.copyLink,
            label: 'Copy',
            icon: LucideIcons.copy,
          ),
        ]),
      ];
    }

    return [
      const MenuSection(actions: [
        MenuAction(
          type: MenuActionType.copyLink,
          label: 'Copy',
          icon: LucideIcons.copy,
        ),
        MenuAction(
          type: MenuActionType.translation,
          label: 'See translation',
          icon: LucideIcons.languages,
        ),
      ]),
      const MenuSection(actions: [
        MenuAction(
          type: MenuActionType.report,
          label: 'Report',
          icon: LucideIcons.flag,
          style: MenuActionStyle.destructive,
        ),
        MenuAction(
          type: MenuActionType.restrict,
          label: 'Restrict',
          icon: LucideIcons.userX,
        ),
        MenuAction(
          type: MenuActionType.block,
          label: 'Block',
          icon: LucideIcons.ban,
          style: MenuActionStyle.destructive,
        ),
      ]),
    ];
  }

  // ── PROFILE MENU ───────────────────────────
  
  static List<MenuSection> _profileSections(MenuContext ctx) {
    if (ctx.isOwner) return [];

    return [
      const MenuSection(actions: [
        MenuAction(
          type: MenuActionType.share,
          label: 'Share this profile',
          icon: LucideIcons.share,
        ),
        MenuAction(
          type: MenuActionType.copyLink,
          label: 'Copy profile URL',
          icon: LucideIcons.link,
        ),
        MenuAction(
          type: MenuActionType.qrCode,
          label: 'QR code',
          icon: LucideIcons.qrCode,
        ),
      ]),
      const MenuSection(actions: [
        MenuAction(
          type: MenuActionType.about,
          label: 'About this account',
          icon: LucideIcons.info,
          showChevron: true,
        ),
        MenuAction(
          type: MenuActionType.notifications,
          label: 'Notifications',
          icon: LucideIcons.bell,
          showChevron: true,
        ),
        MenuAction(
          type: MenuActionType.mute,
          label: 'Mute',
          icon: LucideIcons.bellOff,
          showChevron: true,
        ),
      ]),
      const MenuSection(actions: [
        MenuAction(
          type: MenuActionType.restrict,
          label: 'Restrict',
          icon: LucideIcons.userX,
        ),
        MenuAction(
          type: MenuActionType.block,
          label: 'Block',
          icon: LucideIcons.ban,
          style: MenuActionStyle.destructive,
        ),
        MenuAction(
          type: MenuActionType.report,
          label: 'Report',
          icon: LucideIcons.flag,
          style: MenuActionStyle.destructive,
        ),
      ]),
    ];
  }

  // ── MESSAGE MENU ───────────────────────────
  
  static List<MenuSection> _messageSections(MenuContext ctx) {
    return [
      const MenuSection(actions: [
        MenuAction(
          type: MenuActionType.copyLink,
          label: 'Copy',
          icon: LucideIcons.copy,
        ),
      ]),
      MenuSection(actions: [
        if (ctx.isOwner)
          const MenuAction(
            type: MenuActionType.delete,
            label: 'Unsend',
            icon: LucideIcons.trash2,
            style: MenuActionStyle.destructive,
            requiresConfirmation: true,
          )
        else
          const MenuAction(
            type: MenuActionType.report,
            label: 'Report',
            icon: LucideIcons.flag,
            style: MenuActionStyle.destructive,
          ),
      ]),
    ];
  }
}
