// lib/features/story/presentation/widgets/story_reaction_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StoryReactionBar extends StatefulWidget {
  final void Function(String emoji) onReact;
  final VoidCallback onReply;

  const StoryReactionBar({
    super.key,
    required this.onReact,
    required this.onReply,
  });

  @override
  State<StoryReactionBar> createState() => _StoryReactionBarState();
}

class _StoryReactionBarState extends State<StoryReactionBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double>   _scale;
  bool _expanded = false;

  static const List<String> _emojis = [
    '❤️','😮','😂','😢','😡','🔥','👏',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve:  Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _handleReact(String emoji) {
    HapticFeedback.mediumImpact();
    widget.onReact(emoji);
    _toggleExpand();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize:      MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ─── Emoji row (expanded) ──────────────────────
        if (_expanded)
          ScaleTransition(
            scale: _scale,
            child: Container(
              margin:  const EdgeInsets.only(bottom: 8, right: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical:   8,
              ),
              decoration: BoxDecoration(
                color:        Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _emojis
                    .map(
                      (e) => GestureDetector(
                        onTap: () => _handleReact(e),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            e,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),

        // ─── Bottom row: reply + react ─────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              // Reply field
              Expanded(
                child: GestureDetector(
                  onTap: widget.onReply,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical:   12,
                    ),
                    decoration: BoxDecoration(
                      border:       Border.all(
                        color: Colors.white60,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Send message',
                      style: TextStyle(
                        color:    Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // React button
              GestureDetector(
                onTap: _toggleExpand,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _expanded
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '❤️',
                    style: TextStyle(fontSize: 26),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Share
              GestureDetector(
                onTap: () {},
                child: const Icon(
                  Icons.near_me_outlined,
                  color: Colors.white,
                  size:  28,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
