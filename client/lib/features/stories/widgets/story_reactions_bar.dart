import 'package:flutter/material.dart';

class StoryReactionsBar extends StatelessWidget {
  final Function(String) onReactionTap;
  final bool isVisible;

  const StoryReactionsBar({
    super.key,
    required this.onReactionTap,
    required this.isVisible,
  });

  static const _reactions = ['❤️', '🔥', '😂', '😮', '😢', '👏', '🎉', '💯'];

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      bottom: isVisible ? 70 : -100,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isVisible ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _reactions.map((emoji) {
              return _AnimatedEmojiButton(
                emoji: emoji,
                onTap: () => onReactionTap(emoji),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _AnimatedEmojiButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _AnimatedEmojiButton({required this.emoji, required this.onTap});

  @override
  State<_AnimatedEmojiButton> createState() => _AnimatedEmojiButtonState();
}

class _AnimatedEmojiButtonState extends State<_AnimatedEmojiButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }
}
