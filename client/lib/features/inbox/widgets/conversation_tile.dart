// lib/features/inbox/widgets/conversation_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../models/conversation_model.dart';
import 'conversation_avatar.dart';
import 'typing_indicator.dart';

class ConversationTile extends StatefulWidget {
  final ConversationModel conversation;
  final int index;
  final AnimationController entryController;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onMute;
  final VoidCallback onToggleRead;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.index,
    required this.entryController,
    required this.onTap,
    required this.onDelete,
    required this.onMute,
    required this.onToggleRead,
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

  void _showMoreActionMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conv = widget.conversation;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(conv.isMuted ? LucideIcons.volume_2 : LucideIcons.volume_x),
                title: Text(conv.isMuted ? 'Unmute Notifications' : 'Mute Notifications'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onMute();
                },
              ),
              ListTile(
                leading: Icon(conv.isUnread ? LucideIcons.mail_open : LucideIcons.mail),
                title: Text(conv.isUnread ? 'Mark as Read' : 'Mark as Unread'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onToggleRead();
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.ban, color: Colors.orange),
                title: const Text('Restrict', style: TextStyle(color: Colors.orange)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(LucideIcons.user_minus, color: Colors.red),
                title: const Text('Block User', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(LucideIcons.trash_2, color: Colors.red),
                title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.flag, color: Colors.red),
                title: const Text('Report', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
            ],
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
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFED4956), fontWeight: FontWeight.bold)),
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
            // Extent ratio is thin, snaps back when confirmed dismiss is returned false.
            startActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.15,
              dismissible: DismissiblePane(
                onDismissed: () {},
                confirmDismiss: () async {
                  HapticFeedback.lightImpact();
                  widget.onToggleRead();
                  _triggerBlueFlash();
                  return false; // Snaps back immediately!
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
            
            // SWIPE LEFT ACTIONS SPEC:
            // Reveal 2 buttons (More - grey, Delete - red). Extent 0.4.
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
                      Text('More', style: TextStyle(color: Colors.white, fontSize: 11)),
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
                      Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11)),
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
                            // State-dependent timestamp
                            if (conv.state == ConversationState.sending)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
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
