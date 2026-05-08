// lib/features/chat/presentation/widgets/message_list.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/message.dart';
import '../../../../core/theme/chat_theme.dart';
import 'message_bubble_wrapper.dart';

class MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isTyping;
  final ScrollController scrollController;
  final bool isDark;
  final Function(ChatMessage) onLongPress;
  final Function(ChatMessage) onSwipeReply;
  final Function(ChatMessage) onDoubleTap;
  final Function(String) onTapImage;

  const MessageList({
    super.key,
    required this.messages,
    required this.isTyping,
    required this.scrollController,
    required this.isDark,
    required this.onLongPress,
    required this.onSwipeReply,
    required this.onDoubleTap,
    required this.onTapImage,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isTyping) {
      return _EmptyState(isDark: isDark);
    }

    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
          vertical: 12, horizontal: 12),
      itemCount: messages.length +
          (isTyping ? 1 : 0),
      itemBuilder: (ctx, index) {
        // Typing indicator at the end
        if (isTyping && index == messages.length) {
          return _TypingIndicator(isDark: isDark);
        }

        final msg = messages[index];
        final prev = index > 0
            ? messages[index - 1]
            : null;
        final next = index < messages.length - 1
            ? messages[index + 1]
            : null;

        // Date header
        final showDate = prev == null ||
            !_sameDay(msg.timestamp,
                prev.timestamp);

        // Group logic
        final isFirst = prev == null ||
            prev.senderId != msg.senderId ||
            showDate ||
            msg.timestamp
                    .difference(prev.timestamp)
                    .inMinutes
                    .abs() >
                5;

        final isLast = next == null ||
            next.senderId != msg.senderId ||
            next.timestamp
                    .difference(msg.timestamp)
                    .inMinutes
                    .abs() >
                5;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDate)
              _DateDivider(
                date: msg.timestamp,
                isDark: isDark,
              ),
            MessageBubbleWrapper(
              message: msg,
              isFirst: isFirst,
              isLast: isLast,
              isDark: isDark,
              onLongPress: () =>
                  onLongPress(msg),
              onSwipeReply: () =>
                  onSwipeReply(msg),
              onDoubleTap: () =>
                  onDoubleTap(msg),
              onTapImage: onTapImage,
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;
}

// ── Date Divider ───────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;
  final bool isDark;

  const _DateDivider({
    required this.date,
    required this.isDark,
  });

  String _label() {
    final now = DateTime.now();
    final today =
        DateTime(now.year, now.month, now.day);
    final d = DateTime(
        date.year, date.month, date.day);
    final diff = today.difference(d).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      return [
        'Monday', 'Tuesday', 'Wednesday',
        'Thursday', 'Friday', 'Saturday', 'Sunday'
      ][date.weekday - 1];
    }
    return '${date.day} ${[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.33,
              color: isDark
                  ? ChatColors.separatorDark
                  : ChatColors.separatorLight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12),
            child: Text(
              _label(),
              style: const TextStyle(
                color: ChatColors.secondary,
                fontSize: 12,
                fontFamily:
                    ChatTextStyles.fontFamily,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.33,
              color: isDark
                  ? ChatColors.separatorDark
                  : ChatColors.separatorLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing Indicator ───────────────────────

class _TypingIndicator extends StatefulWidget {
  final bool isDark;

  const _TypingIndicator({required this.isDark});

  @override
  State<_TypingIndicator> createState() =>
      _TypingIndicatorState();
}

class _TypingIndicatorState
    extends State<_TypingIndicator>
    with TickerProviderStateMixin {

  late List<AnimationController> _dots;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _dots = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _anims = _dots.map((c) =>
      Tween<double>(begin: 0, end: -6)
          .animate(CurvedAnimation(
              parent: c,
              curve: Curves.easeInOut))
    ).toList();

    // Stagger
    for (int i = 0; i < 3; i++) {
      Future.delayed(
          Duration(milliseconds: i * 150), () {
        if (mounted) {
          _dots[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: 12, bottom: 8, top: 4),
      child: Row(
        children: [
          // Small avatar placeholder
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isDark
                  ? ChatColors.darkCard
                  : ChatColors.receivedLight,
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? ChatColors.receivedDark
                  : ChatColors.receivedLight,
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _anims[i],
                  builder: (ctx, _) => Transform.translate(
                    offset: Offset(0, _anims[i].value),
                    child: Container(
                      width: 7,
                      height: 7,
                      margin: EdgeInsets.only(
                          right: i < 2 ? 4 : 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ChatColors.secondary
                            .withOpacity(0.7),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _dots) c.dispose();
    super.dispose();
  }
}

// ── Empty State ────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.messageCircle,
            size: 56,
            color: isDark
                ? Colors.white.withOpacity(0.15)
                : Colors.black.withOpacity(0.08),
          ),
          const SizedBox(height: 14),
          const Text(
            'No messages yet',
            style: TextStyle(
              color: ChatColors.secondary,
              fontSize: 15,
              fontFamily: ChatTextStyles.fontFamily,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Send a message to get started',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withOpacity(0.25)
                  : const Color(0xFFBBBBBB),
              fontSize: 13,
              fontFamily: ChatTextStyles.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
