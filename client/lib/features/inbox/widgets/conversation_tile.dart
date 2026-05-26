// lib/features/inbox/widgets/conversation_tile.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../models/conversation_model.dart';
import 'conversation_avatar.dart';
import 'typing_indicator.dart';
import '../../messages/presentation/widgets/chat/mute_bottom_sheet.dart';
import '../../messages/presentation/widgets/chat/report_sheet.dart';

class ConversationTile extends StatefulWidget {
  final ConversationModel conversation;
  final int index;
  final AnimationController entryController;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<String>? onMute;
  final VoidCallback? onUnmute;
  final VoidCallback? onToggleRead;
  final Future<void> Function(String type, String desc)? onReport;
  final VoidCallback? onBlock;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.index,
    required this.entryController,
    required this.onTap,
    required this.onDelete,
    this.onMute,
    this.onUnmute,
    this.onToggleRead,
    this.onReport,
    this.onBlock,
  });

  @override
  State<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile>
    with TickerProviderStateMixin {
  
  late Animation<double> _entryOpacity;
  late Animation<Offset> _entrySlide;
  
  // Custom micro-animations
  bool _isPressed = false;
  bool _showBlueFlash = false;
  double _avatarScale = 1.0;

  @override
  void initState() {
    super.initState();
    
    // Cascading entry animations: Max 8 items staggered
    final double delay = (widget.index * 0.05).clamp(0.0, 0.4);
    final double end = (delay + 0.3).clamp(0.0, 1.0);

    _entryOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: widget.entryController,
        curve: Interval(delay, end, curve: Curves.easeOut),
      ),
    );

    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: widget.entryController,
        curve: Interval(delay, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  void _triggerBlueFlash() {
    if (!mounted) return;
    setState(() {
      _showBlueFlash = true;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _showBlueFlash = false;
        });
      }
    });
  }

  void _animateAvatarPress(bool pressed) {
    setState(() {
      _avatarScale = pressed ? 0.94 : 1.0;
    });
  }

  /// iOS-style blurred glass popup menu
  void _showMoreActionMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conv = widget.conversation;
    // Capture root navigator context BEFORE opening any dialog
    final rootContext = context;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
            alignment: Alignment.center,
            child: _IosStyleMenu(
              isDark: isDark,
              conv: conv,
              onMute: () {
                Navigator.of(ctx).pop();
                // Show mute duration picker using root context
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (!rootContext.mounted) return;
                  showModalBottomSheet(
                    context: rootContext,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (sheetCtx) => MuteBottomSheet(
                      username: conv.username,
                      onMuteSelected: (duration) {
                        Navigator.pop(sheetCtx);
                        widget.onMute?.call(duration);
                      },
                    ),
                  );
                });
              },
              onUnmute: () {
                Navigator.of(ctx).pop();
                widget.onUnmute?.call();
              },
              onToggleRead: () {
                Navigator.of(ctx).pop();
                widget.onToggleRead?.call();
              },
              onBlock: () {
                Navigator.of(ctx).pop();
                widget.onBlock?.call();
              },
              onReport: () {
                Navigator.of(ctx).pop();
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (!rootContext.mounted) return;
                  showModalBottomSheet(
                    context: rootContext,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ReportSheet(
                      targetName: conv.username,
                      onSubmitReport: (type, desc) async {
                        await widget.onReport?.call(type, desc);
                      },
                    ),
                  );
                });
              },
              onDelete: () {
                Navigator.of(ctx).pop();
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (!rootContext.mounted) return;
                  _confirmDeleteDialog(rootContext);
                });
              },
              onLeaveGroup: () {
                Navigator.of(ctx).pop();
                widget.onDelete();
              },
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF262626) : Colors.white,
        title: const Text('Delete Conversation?'),
        content: Text('Are you sure you want to permanently delete this chat with ${widget.conversation.username}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, decoration: TextDecoration.none)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFED4956), fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Subtle blue background if unread
    final Color unreadBg = isDark
        ? const Color(0xFF0095F6).withValues(alpha: 0.05)
        : const Color(0xFF0095F6).withValues(alpha: 0.03);

    final Color pressBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.withValues(alpha: 0.1);

    final Color tileColor = _isPressed
        ? pressBg
        : conv.isUnread
            ? unreadBg
            : Colors.transparent;

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _entryOpacity,
        child: SlideTransition(
          position: _entrySlide,
          child: Slidable(
            key: ValueKey(conv.id),
            // SWIPE RIGHT TO MARK READ/UNREAD SPEC:
            startActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.15,
              dismissible: DismissiblePane(
                onDismissed: () {},
                confirmDismiss: () async {
                  HapticFeedback.lightImpact();
                  widget.onToggleRead?.call();
                  _triggerBlueFlash();
                  return false;
                },
              ),
              children: [
                Expanded(
                  child: Container(
                    color: const Color(0xFF0095F6).withValues(alpha: 0.2),
                    alignment: Alignment.center,
                    child: Icon(
                      conv.isUnread ? LucideIcons.mail_open : LucideIcons.mail,
                      color: const Color(0xFF0095F6),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            
            // SWIPE LEFT ACTIONS
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.4,
              children: [
                CustomSlidableAction(
                  onPressed: (context) => _showMoreActionMenu(context),
                  backgroundColor: const Color(0xFF8E8E93),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.more_horiz, color: Colors.white, size: 24),
                      SizedBox(height: 4),
                      Text('More', style: TextStyle(color: Colors.white, fontSize: 11, decoration: TextDecoration.none)),
                    ],
                  ),
                ),
                CustomSlidableAction(
                  onPressed: (context) => _confirmDeleteDialog(context),
                  backgroundColor: const Color(0xFFED4956),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.trash_2, color: Colors.white, size: 24),
                      SizedBox(height: 4),
                      Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11, decoration: TextDecoration.none)),
                    ],
                  ),
                ),
              ],
            ),
            
            child: Stack(
              children: [
                GestureDetector(
                  onTapDown: (_) {
                    setState(() => _isPressed = true);
                    _animateAvatarPress(true);
                  },
                  onTapUp: (_) {
                    setState(() => _isPressed = false);
                    _animateAvatarPress(false);
                    widget.onTap();
                  },
                  onTapCancel: () {
                    setState(() => _isPressed = false);
                    _animateAvatarPress(false);
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    _showMoreActionMenu(context);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    color: tileColor,
                    height: 72,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // AVATAR AREA (left) with Press scale feedback
                        AnimatedScale(
                          scale: _avatarScale,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutBack,
                          child: ConversationAvatar(conversation: conv),
                        ),
                        const SizedBox(width: 12),

                        // CONTENT AREA (middle, expanded)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Username row
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      conv.isGroup ? (conv.username.isEmpty ? 'Group Chat' : conv.username) : conv.username,
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Display',
                                        fontSize: 15,
                                        fontWeight: conv.isUnread
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black,
                                        decoration: TextDecoration.none,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (conv.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified,
                                      color: Color(0xFF0095F6),
                                      size: 14,
                                    ),
                                  ],
                                  if (conv.isMuted) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      LucideIcons.volume_x,
                                      color: Colors.grey.withValues(alpha: 0.6),
                                      size: 13,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),

                              // Last message row or typing indicator
                              conv.isTyping
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 4.0),
                                      child: TypingIndicator(),
                                    )
                                  : Text(
                                      conv.lastMessagePreview,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: conv.isUnread
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: conv.isUnread
                                            ? (isDark ? Colors.white : Colors.black87)
                                            : Colors.grey,
                                        decoration: TextDecoration.none,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // TIME & UNREAD STATUS (right)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (conv.state == ConversationState.sending)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CupertinoActivityIndicator(
                                  radius: 6,
                                  color: Colors.grey,
                                ),
                              )
                            else if (conv.state == ConversationState.failed)
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFED4956),
                                size: 16,
                              )
                            else
                              Text(
                                conv.isActive ? 'Active now' : conv.timeDisplay,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: conv.isActive
                                      ? const Color(0xFF09C167)
                                      : Colors.grey.withValues(alpha: 0.8),
                                  fontWeight: conv.isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            const SizedBox(height: 6),

                            // Unread blue dot with pop animation
                            AnimatedScale(
                              scale: conv.isUnread ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.elasticOut,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0095F6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // BLUE FLASH ANIMATION OVERLAY
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _showBlueFlash ? 0.35 : 0.0,
                      duration: const Duration(milliseconds: 80),
                      child: Container(
                        color: const Color(0xFF0095F6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// iOS-style frosted glass popup menu
// ──────────────────────────────────────────────────────────────────

class _IosStyleMenu extends StatelessWidget {
  final bool isDark;
  final ConversationModel conv;
  final VoidCallback onMute;
  final VoidCallback onUnmute;
  final VoidCallback onToggleRead;
  final VoidCallback onBlock;
  final VoidCallback onReport;
  final VoidCallback onDelete;
  final VoidCallback onLeaveGroup;

  const _IosStyleMenu({
    required this.isDark,
    required this.conv,
    required this.onMute,
    required this.onUnmute,
    required this.onToggleRead,
    required this.onBlock,
    required this.onReport,
    required this.onDelete,
    required this.onLeaveGroup,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? const Color(0xFF2C2C2E).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.68);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final separatorColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    final List<_MenuAction> actions = [
      _MenuAction(
        icon: conv.isMuted ? LucideIcons.volume_2 : LucideIcons.bell_off,
        label: conv.isMuted ? 'Unmute Notifications' : 'Mute Notifications',
        onTap: conv.isMuted ? onUnmute : onMute,
      ),
      _MenuAction(
        icon: conv.isUnread ? LucideIcons.mail_open : LucideIcons.mail,
        label: conv.isUnread ? 'Mark as Read' : 'Mark as Unread',
        onTap: onToggleRead,
      ),
      if (!conv.isGroup) ...[
        _MenuAction(
          icon: LucideIcons.user_minus,
          label: 'Block',
          onTap: onBlock,
          isDestructive: true,
        ),
        _MenuAction(
          icon: LucideIcons.flag,
          label: 'Report',
          onTap: onReport,
          isDestructive: true,
        ),
        _MenuAction(
          icon: LucideIcons.trash_2,
          label: 'Delete Chat',
          onTap: onDelete,
          isDestructive: true,
        ),
      ] else ...[
        _MenuAction(
          icon: LucideIcons.log_out,
          label: 'Leave Group',
          onTap: onLeaveGroup,
          isDestructive: true,
        ),
      ],
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                    blurRadius: 30,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header: conversation name
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          conv.username.isEmpty ? 'Group Chat' : conv.username,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor.withValues(alpha: 0.55),
                            fontFamily: 'SF Pro Display',
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 0.5, thickness: 0.5, color: separatorColor),
                  // Menu items
                  ...actions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final action = entry.value;
                    final isLast = i == actions.length - 1;
                    final itemColor = action.isDestructive
                        ? const Color(0xFFFF3B30)
                        : textColor;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MenuItemTile(
                          icon: action.icon,
                          label: action.label,
                          color: itemColor,
                          onTap: action.onTap,
                          isDark: isDark,
                        ),
                        if (!isLast)
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: separatorColor,
                            indent: 16,
                            endIndent: 16,
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}

class _MenuItemTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _MenuItemTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_MenuItemTile> createState() => _MenuItemTileState();
}

class _MenuItemTileState extends State<_MenuItemTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final highlightColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        color: _pressed ? highlightColor : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: widget.color,
                  fontFamily: 'SF Pro Display',
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Icon(widget.icon, size: 20, color: widget.color),
          ],
        ),
      ),
    );
  }
}
