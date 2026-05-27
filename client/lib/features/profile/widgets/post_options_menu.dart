// lib/features/profile/widgets/post_options_menu.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:instagram_client/features/post/data/models/post_model.dart';
import 'package:instagram_client/core/theme/ios_colors.dart';

enum PostAction {
  pin, unpin, archive, unarchive,
  edit, hideLikes, showLikes,
  turnOffComments, turnOnComments,
  editAudience, delete, copyLink, share
}

class IosSheetAction {
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const IosSheetAction({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}

void showIosActionSheet({
  required BuildContext context,
  required List<IosSheetAction> actions,
}) {
  showCupertinoModalPopup(
    context: context,
    builder: (BuildContext context) => CupertinoActionSheet(
      actions: actions
          .map(
            (action) => CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                action.onTap();
              },
              isDestructiveAction: action.isDestructive,
              child: Text(action.label),
            ),
          )
          .toList(),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ),
  );
}

class PostOptionsMenu {
  static void show({
    required BuildContext context,
    required PostModel post,
    required bool isOwnPost,
    required Function(PostAction) onAction,
  }) {
    HapticFeedback.mediumImpact();

    if (!isOwnPost) {
      _showOtherUserMenu(context, post, onAction);
      return;
    }

    _showOwnPostMenu(context, post, onAction);
  }

  static void _showOwnPostMenu(
    BuildContext context,
    PostModel post,
    Function(PostAction) onAction,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OwnPostOptionsSheet(
        post: post,
        isDark: isDark,
        onAction: onAction,
      ),
    );
  }

  static void _showOtherUserMenu(
    BuildContext context,
    PostModel post,
    Function(PostAction) onAction,
  ) {
    showIosActionSheet(
      context: context,
      actions: [
        IosSheetAction(label: 'Copy link', onTap: () => onAction(PostAction.copyLink)),
        IosSheetAction(label: 'Share to...', onTap: () => onAction(PostAction.share)),
        IosSheetAction(label: 'Report', isDestructive: true, onTap: () {}),
      ],
    );
  }
}

// ── Own Post Options Sheet ──
class _OwnPostOptionsSheet extends StatefulWidget {
  final PostModel post;
  final bool isDark;
  final Function(PostAction) onAction;

  const _OwnPostOptionsSheet({
    required this.post,
    required this.isDark,
    required this.onAction,
  });

  @override
  State<_OwnPostOptionsSheet> createState() =>
      _OwnPostOptionsSheetState();
}

class _OwnPostOptionsSheetState extends State<_OwnPostOptionsSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.5),
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _doAction(PostAction action) {
    _ctrl.reverse().then((_) {
      Navigator.pop(context);
      widget.onAction(action);
    });
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        onTap: () => _ctrl.reverse().then((_) => Navigator.pop(context)),
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // don't dismiss
            child: SlideTransition(
              position: _slide,
              child: Container(
                margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    const SizedBox(height: 8),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                          ? const Color(0xFF48484A)
                          : const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Post thumbnail preview
                    _PostPreviewHeader(post: post, isDark: isDark),

                    const Divider(height: 0.5),

                    // ── Actions ──
                    _buildMenuItem(
                      icon: post.isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                      label: post.isPinned
                        ? 'Unpin from profile'
                        : 'Pin to your profile',
                      isDark: isDark,
                      onTap: () => _doAction(
                        post.isPinned
                          ? PostAction.unpin
                          : PostAction.pin,
                      ),
                      showBadge: !post.isPinned,
                      badgeLabel: 'New',
                    ),

                    _buildMenuItem(
                      icon: post.isArchived
                        ? CupertinoIcons.tray_arrow_up
                        : CupertinoIcons.archivebox,
                      label: post.isArchived
                        ? 'Unarchive'
                        : 'Archive',
                      isDark: isDark,
                      onTap: () => _doAction(
                        post.isArchived
                          ? PostAction.unarchive
                          : PostAction.archive,
                      ),
                    ),

                    _buildMenuItem(
                      icon: CupertinoIcons.pencil,
                      label: 'Edit',
                      isDark: isDark,
                      onTap: () => _doAction(PostAction.edit),
                    ),

                    _buildMenuItem(
                      icon: post.hideLikesCount
                        ? CupertinoIcons.eye
                        : CupertinoIcons.eye_slash,
                      label: post.hideLikesCount
                        ? 'Unhide like count'
                        : 'Hide like count',
                      isDark: isDark,
                      onTap: () => _doAction(
                        post.hideLikesCount
                          ? PostAction.showLikes
                          : PostAction.hideLikes,
                      ),
                    ),

                    _buildMenuItem(
                      icon: post.commentsDisabled
                        ? CupertinoIcons.chat_bubble
                        : CupertinoIcons.chat_bubble_text,
                      label: post.commentsDisabled
                        ? 'Turn on commenting'
                        : 'Turn off commenting',
                      isDark: isDark,
                      onTap: () => _doAction(
                        post.commentsDisabled
                          ? PostAction.turnOnComments
                          : PostAction.turnOffComments,
                      ),
                    ),

                    _buildMenuItem(
                      icon: CupertinoIcons.person_2,
                      label: 'Edit audience',
                      subtitle: _audienceLabel(post.audience),
                      isDark: isDark,
                      onTap: () => _doAction(PostAction.editAudience),
                    ),

                    _buildMenuItem(
                      icon: CupertinoIcons.link,
                      label: 'Copy link',
                      isDark: isDark,
                      onTap: () => _doAction(PostAction.copyLink),
                    ),

                    const Divider(height: 8),

                    _buildMenuItem(
                      icon: CupertinoIcons.delete,
                      label: 'Delete',
                      isDark: isDark,
                      isDestructive: true,
                      onTap: () => _confirmDelete(),
                    ),

                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    String? subtitle,
    bool isDestructive = false,
    bool showBadge = false,
    String? badgeLabel,
  }) {
    return _SheetMenuItem(
      icon: icon,
      label: label,
      subtitle: subtitle,
      isDark: isDark,
      isDestructive: isDestructive,
      showBadge: showBadge,
      badgeLabel: badgeLabel,
      onTap: onTap,
    );
  }

  String _audienceLabel(PostAudience audience) {
    switch (audience) {
      case PostAudience.everyone: return 'Everyone';
      case PostAudience.followers: return 'Followers';
      case PostAudience.closeFriends: return 'Close Friends';
      case PostAudience.onlyMe: return 'Only Me';
    }
  }

  void _confirmDelete() {
    Navigator.pop(context);
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete post?'),
        content: const Text(
          'Are you sure you want to delete this post? '
          'This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              widget.onAction(PostAction.delete);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Sheet Menu Item ──
class _SheetMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDark;
  final bool isDestructive;
  final bool showBadge;
  final String? badgeLabel;
  final VoidCallback onTap;

  const _SheetMenuItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
    this.showBadge = false,
    this.badgeLabel,
  });

  @override
  State<_SheetMenuItem> createState() => _SheetMenuItemState();
}

class _SheetMenuItemState extends State<_SheetMenuItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive
      ? const Color(0xFFED4956)
      : IosColors.primary(context);

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressed
          ? (widget.isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04))
          : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Icon
            SizedBox(
              width: 28,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(widget.icon, size: 24, color: color),
                  if (widget.showBadge && widget.badgeLabel != null)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.elasticOut,
                        builder: (_, v, __) => Transform.scale(
                          scale: v,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0095F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.badgeLabel!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Label + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        color: IosColors.secondary(context),
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Chevron for navigable items
            if (widget.subtitle != null)
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: IosColors.secondary(context),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Post Preview Header in Sheet ──
class _PostPreviewHeader extends StatelessWidget {
  final PostModel post;
  final bool isDark;

  const _PostPreviewHeader({
    required this.post,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Thumbnail
          if (post.mediaUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: post.mediaUrls.first,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 12),

          // Caption
          Expanded(
            child: Text(
              post.caption == null || post.caption!.isEmpty
                ? 'No caption'
                : post.caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: IosColors.primary(context),
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ),

          // Status badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (post.isPinned)
                _StatusBadge(
                  icon: Icons.push_pin,
                  label: 'Pinned',
                  color: const Color(0xFF0095F6),
                ),
              if (post.hideLikesCount)
                _StatusBadge(
                  icon: CupertinoIcons.eye_slash,
                  label: 'Likes hidden',
                  color: IosColors.secondary(context),
                ),
              if (post.commentsDisabled)
                _StatusBadge(
                  icon: CupertinoIcons.chat_bubble_text,
                  label: 'Comments off',
                  color: IosColors.secondary(context),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
