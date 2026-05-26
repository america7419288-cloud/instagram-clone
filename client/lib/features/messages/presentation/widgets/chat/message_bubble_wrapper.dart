import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, Divider, CircleAvatar, ListTile, showModalBottomSheet, ClipOval, Image, NetworkImage, SizedBox, GestureDetector, Row, Padding, BuildContext, MainAxisSize, CrossAxisAlignment, Stack, Positioned, ClipRRect, BackdropFilter, Container, Widget, Expanded, ListView;
import 'dart:ui' show ImageFilter;
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../../chat/data/models/chat_user.dart';
import 'chat_ui_constants.dart';

class MessageBubbleWrapper extends StatefulWidget {
  final Widget child;
  final bool isSent;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final String? senderAvatar;
  final VoidCallback onReply;
  final VoidCallback onDoubleTap;
  final void Function(Offset position, Size size)? onLongPress;
  final Widget? statusRow;
  final Widget? reactionsChip;
  final Widget? replyQuote;
  final VoidCallback? onAvatarTap;
  final List<ChatUser>? seenParticipants;

  const MessageBubbleWrapper({
    super.key,
    required this.child,
    required this.isSent,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    this.senderAvatar,
    required this.onReply,
    required this.onDoubleTap,
    this.onLongPress,
    this.statusRow,
    this.reactionsChip,
    this.replyQuote,
    this.onAvatarTap,
    this.seenParticipants,
  });

  @override
  State<MessageBubbleWrapper> createState() => _MessageBubbleWrapperState();
}

class _MessageBubbleWrapperState extends State<MessageBubbleWrapper>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  static const double _maxDragOffset = 72.0;
  static const double _replyThreshold = 50.0;
  bool _thresholdReached = false;
  final GlobalKey _bubbleKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final hasReactions = widget.reactionsChip != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: widget.isFirstInGroup ? 8 : 2,
        bottom: widget.isLastInGroup
            ? (hasReactions ? 14 : 4)
            : (hasReactions ? 10 : 0),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reply Icon Indicator
          if (_dragOffset != 0)
            Positioned(
              left: widget.isSent ? null : -40 + (_dragOffset.abs() * 0.5),
              right: widget.isSent ? -40 + (_dragOffset.abs() * 0.5) : null,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: (_dragOffset.abs() / _maxDragOffset).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale:
                        0.5 +
                        ((_dragOffset.abs() / _maxDragOffset).clamp(0.0, 1.0) *
                            0.5),
                    child: const Icon(
                      LucideIcons.corner_up_left,
                      size: 22,
                      color: ChatUIConstants.textSecondaryLight,
                    ),
                  ),
                ),
              ),
            ),

          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                if (widget.isSent) {
                  // Sent: swipe left (delta.dx < 0)
                  if (details.delta.dx < 0 || _dragOffset < 0) {
                    _dragOffset = (_dragOffset + details.delta.dx).clamp(
                      -_maxDragOffset,
                      0.0,
                    );
                  }
                } else {
                  // Received: swipe right (delta.dx > 0)
                  if (details.delta.dx > 0 || _dragOffset > 0) {
                    _dragOffset = (_dragOffset + details.delta.dx).clamp(
                      0.0,
                      _maxDragOffset,
                    );
                  }
                }

                if (_dragOffset.abs() >= _replyThreshold &&
                    !_thresholdReached) {
                  _thresholdReached = true;
                  HapticFeedback.mediumImpact();
                } else if (_dragOffset.abs() < _replyThreshold) {
                  _thresholdReached = false;
                }
              });
            },
            onHorizontalDragEnd: (details) {
              if (_thresholdReached) {
                widget.onReply();
              }
              setState(() {
                _dragOffset = 0.0;
                _thresholdReached = false;
              });
            },
            onDoubleTap: () {
              HapticFeedback.lightImpact();
              widget.onDoubleTap();
            },
            onLongPress: () {
              HapticFeedback.heavyImpact();
              if (widget.onLongPress != null) {
                final RenderBox? renderBox =
                    _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox != null && renderBox.hasSize) {
                  final offset = renderBox.localToGlobal(Offset.zero);
                  widget.onLongPress!(offset, renderBox.size);
                } else {
                  widget.onLongPress!(Offset.zero, Size.zero);
                }
              }
            },
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Row(
                mainAxisAlignment: widget.isSent
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!widget.isSent) ...[
                    _buildAvatar(),
                    const SizedBox(width: 6),
                  ],
                  _buildBubbleColumn(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return SizedBox(
      width: 28,
      height: 28,
      child: widget.isLastInGroup && widget.senderAvatar != null
          ? GestureDetector(
              onTap: widget.onAvatarTap,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ChatUIConstants.separatorLight,
                  image: DecorationImage(
                    image: NetworkImage(widget.senderAvatar!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildBubbleColumn() {
    final hasReactions = widget.reactionsChip != null;
    Widget bubbleContent = widget.child;

    if (hasReactions) {
      bubbleContent = Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            bottom: -8, // Overlap the bottom border
            right: widget.isSent ? 10 : null, // Bottom right for sent
            left: widget.isSent ? null : 10,  // Bottom left for received
            child: widget.reactionsChip!,
          ),
        ],
      );
    }

    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: widget.isSent
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (widget.replyQuote != null) widget.replyQuote!,
        Container(
          key: _bubbleKey,
          child: bubbleContent,
        ),
        if (widget.isSent && widget.isLastInGroup && widget.statusRow != null && (widget.seenParticipants == null || widget.seenParticipants!.isEmpty))
          Padding(
            padding: EdgeInsets.only(top: hasReactions ? 10.0 : 0.0),
            child: widget.statusRow!,
          ),
        if (widget.seenParticipants != null && widget.seenParticipants!.isNotEmpty)
          SeenAvatarsRow(
            participants: widget.seenParticipants!,
            isSent: widget.isSent,
            isDark: isDark,
          ),
      ],
    );
  }
}

class StatusRow extends StatelessWidget {
  final String status; // 'sending', 'sent', 'delivered', 'seen', 'failed'

  const StatusRow({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3, right: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'seen') ...[
            const Text(
              "Seen",
              style: TextStyle(
                fontSize: 11,
                color: ChatUIConstants.verifiedBlue,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 2),
          ],
          if (status == 'failed') ...[
            const Text(
              "Failed",
              style: TextStyle(
                fontSize: 11,
                color: ChatUIConstants.likeRed,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 2),
          ],
          _buildIcon(),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    switch (status) {
      case 'sending':
        return const Icon(
          LucideIcons.clock,
          size: 11,
          color: ChatUIConstants.textSecondaryLight,
        );
      case 'sent':
        return const Icon(
          LucideIcons.check,
          size: 11,
          color: ChatUIConstants.textSecondaryLight,
        );
      case 'delivered':
        return const Icon(
          LucideIcons.check_check,
          size: 11,
          color: ChatUIConstants.textSecondaryLight,
        );
      case 'seen':
        return const Icon(
          LucideIcons.check_check,
          size: 11,
          color: ChatUIConstants.verifiedBlue,
        );
      case 'failed':
        return const Icon(
          LucideIcons.circle_alert,
          size: 11,
          color: ChatUIConstants.likeRed,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class ReplyQuoteBox extends StatelessWidget {
  final String username;
  final String text;
  final String? imageUrl;
  final bool isSent;

  const ReplyQuoteBox({
    super.key,
    required this.username,
    required this.text,
    this.imageUrl,
    required this.isSent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    final bgColor = isSent
        ? CupertinoColors.black.withOpacity(0.18)
        : (isDark
              ? CupertinoColors.white.withOpacity(0.07)
              : CupertinoColors.black.withOpacity(0.05));

    final accentColor = isSent
        ? CupertinoColors.white.withOpacity(0.55)
        : ChatUIConstants.verifiedBlue;
    final nameColor = isSent
        ? CupertinoColors.white.withOpacity(0.85)
        : ChatUIConstants.verifiedBlue;
    final textColor = isSent
        ? CupertinoColors.white.withOpacity(0.60)
        : (isDark
              ? ChatUIConstants.textSecondaryDark
              : ChatUIConstants.textSecondaryLight);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: nameColor,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: textColor,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            if (imageUrl != null) ...[
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  imageUrl!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReactionsChip extends StatelessWidget {
  final Map<String, int> reactions;
  final bool isSent;

  const ReactionsChip({
    super.key,
    required this.reactions,
    required this.isSent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF3E3E40) : const Color(0xFFE2E2E4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(isDark ? 0.35 : 0.09),
            blurRadius: 5,
            spreadRadius: 0.5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.entries.map((e) {
          final countText = e.value > 1 ? " ${e.value}" : "";
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              "${e.key}$countText",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
                decoration: TextDecoration.none,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Seen Avatars Row ──────────────────────────────────────
class SeenAvatarsRow extends StatelessWidget {
  final List<ChatUser> participants;
  final bool isSent;
  final bool isDark;

  const SeenAvatarsRow({
    super.key,
    required this.participants,
    required this.isSent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) return const SizedBox.shrink();

    // Show max 5 avatars
    final displayList = participants.take(5).toList();
    final remainingCount = participants.length - displayList.length;

    return GestureDetector(
      onTap: () => _showSeenListSheet(context),
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            SizedBox(
              height: 16,
              width: (displayList.length - 1) * 10.0 + 14.0,
              child: Stack(
                clipBehavior: Clip.none,
                children: List.generate(displayList.length, (index) {
                  final user = displayList[index];
                  final offset = index * 10.0;
                  return Positioned(
                    left: isSent ? null : offset,
                    right: isSent ? offset : null,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF121212) : Colors.white,
                          width: 1,
                        ),
                        color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                      ),
                      child: ClipOval(
                        child: user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty
                            ? Image.network(
                                user.profilePicUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  LucideIcons.user,
                                  size: 8,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              )
                            : Icon(
                                LucideIcons.user,
                                size: 8,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (remainingCount > 0) ...[
              const SizedBox(width: 6),
              Text(
                "+$remainingCount",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white54 : Colors.black54,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSeenListSheet(BuildContext context) {
    final textTheme = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final bgColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.94);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Material(
            color: bgColor,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5,
              padding: const EdgeInsets.only(bottom: 24, top: 8),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white30 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.eye,
                            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Seen by',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: textTheme,
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${participants.length}',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 0.5, thickness: 0.5),
                    Expanded(
                      child: ListView.builder(
                        itemCount: participants.length,
                        itemBuilder: (ctx, index) {
                          final user = participants[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                              backgroundImage: user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty
                                  ? NetworkImage(user.profilePicUrl!)
                                  : null,
                              child: user.profilePicUrl == null
                                  ? Icon(LucideIcons.user, size: 18, color: isDark ? Colors.white54 : Colors.black54)
                                  : null,
                            ),
                            title: Text(
                              user.username,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textTheme,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: user.fullName != null
                                ? Text(
                                    user.fullName!,
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.black54,
                                      fontSize: 13,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
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
}
