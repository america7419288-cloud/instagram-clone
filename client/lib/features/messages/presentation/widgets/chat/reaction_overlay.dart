import 'package:flutter/cupertino.dart';
import 'chat_ui_constants.dart';

class ReactionOverlay extends StatelessWidget {
  final Offset messageOffset;
  final Size messageSize;
  final bool isSent;
  final Function(String) onReact;
  final List<String> actions;
  final Function(String) onAction;

  const ReactionOverlay({
    super.key,
    required this.messageOffset,
    required this.messageSize,
    required this.isSent,
    required this.onReact,
    required this.actions,
    required this.onAction,
  });

  static Future<void> show({
    required BuildContext context,
    required Offset messageOffset,
    required Size messageSize,
    required bool isSent,
    required Function(String) onReact,
    required List<String> actions,
    required Function(String) onAction,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: CupertinoColors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CupertinoTheme(
          data: CupertinoTheme.of(context),
          child: DefaultTextStyle(
            style: CupertinoTheme.of(context).textTheme.textStyle,
            child: ReactionOverlay(
              messageOffset: messageOffset,
              messageSize: messageSize,
              isSent: isSent,
              onReact: onReact,
              actions: actions,
              onAction: onAction,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    
    // Position the emoji bar above the message
    double emojiTop = messageOffset.dy - 60;
    if (emojiTop < 60) emojiTop = messageOffset.dy + messageSize.height + 10;

    // Position the action sheet below the message
    double actionTop = messageOffset.dy + messageSize.height + 10;
    if (actionTop + 260 > MediaQuery.of(context).size.height) {
      actionTop = messageOffset.dy - 270;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: CupertinoColors.transparent),
          ),
        ),
        
        // Emoji Bar
        Positioned(
          top: emojiTop,
          left: isSent ? null : 20,
          right: isSent ? 20 : null,
          child: _buildEmojiBar(isDark),
        ),

        // Action Sheet
        Positioned(
          top: actionTop,
          left: isSent ? null : 20,
          right: isSent ? 20 : null,
          child: _buildActionSheet(isDark),
        ),
      ],
    );
  }

  Widget _buildEmojiBar(bool isDark) {
    final emojis = ["❤️", "😂", "😮", "😢", "😡", "👏"];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: CupertinoColors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...emojis.map((emoji) => _EmojiItem(emoji: emoji, onTap: onReact)),
          _EmojiItem(emoji: "+", onTap: (_) {}),
        ],
      ),
    );
  }

  Widget _buildActionSheet(bool isDark) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(actions.length, (index) {
          final action = actions[index];
          final isDestructive = action == 'Unsend' || action == 'Report';
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onPressed: () => onAction(action),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      action,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDestructive ? ChatUIConstants.likeRed : (isDark ? CupertinoColors.white : CupertinoColors.black),
                      ),
                    ),
                    // Icons could be added here based on action name
                  ],
                ),
              ),
              if (index < actions.length - 1)
                Container(
                  height: 0.33,
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFDBDBDB),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _EmojiItem extends StatefulWidget {
  final String emoji;
  final Function(String) onTap;

  const _EmojiItem({required this.emoji, required this.onTap});

  @override
  State<_EmojiItem> createState() => _EmojiItemState();
}

class _EmojiItemState extends State<_EmojiItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) {
        setState(() => _isHovered = false);
        widget.onTap(widget.emoji);
      },
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        transform: Matrix4.identity()..scale(_isHovered ? 1.3 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(widget.emoji, style: const TextStyle(fontSize: 24, decoration: TextDecoration.none)),
      ),
    );
  }
}
