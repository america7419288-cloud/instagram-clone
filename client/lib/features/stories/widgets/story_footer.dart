import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/story_model.dart';
import 'story_music_bar.dart';

class StoryFooter extends StatefulWidget {
  final StoryModel story;
  final bool isOwner;
  final Function(String) onReply;
  final Function(String) onReaction;
  final VoidCallback onShare;
  final Function(bool) onFocusChanged;

  const StoryFooter({
    super.key,
    required this.story,
    required this.isOwner,
    required this.onReply,
    required this.onReaction,
    required this.onShare,
    required this.onFocusChanged,
  });

  @override
  State<StoryFooter> createState() => _StoryFooterState();
}

class _StoryFooterState extends State<StoryFooter>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;

  // Reactions
  static const _reactions = ['❤️', '🔥', '😂', '😮', '😢', '👏'];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
      widget.onFocusChanged(_focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOwner) {
      return _buildOwnerFooter();
    }
    return _buildViewerFooter();
  }

  // ─── Viewer footer ─────────────────────────────────
  Widget _buildViewerFooter() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Music bar (if story has music)
            if (widget.story.music != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StoryMusicBar(
                  music: widget.story.music!,
                  isPlaying: true, // Playing by default
                ),
              ),

            // Input row
            Row(
              children: [
                // Reply text field
                Expanded(
                  child: GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 44,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isFocused
                              ? Colors.white
                              : Colors.white.withOpacity(0.6),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                hintText: widget.story.question != null
                                    ? 'Answer...'
                                    : 'Send message',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              cursorColor: Colors.white,
                              onSubmitted: (val) {
                                if (val.isNotEmpty) {
                                  widget.onReply(val);
                                  _controller.clear();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Reaction emojis (when not focused)
                if (!_isFocused) ...[
                  for (final emoji in _reactions)
                    _ReactionButton(
                      emoji: emoji,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onReaction(emoji);
                      },
                    ),
                  const SizedBox(width: 4),
                ],

                // Share button
                if (!_isFocused)
                  GestureDetector(
                    onTap: widget.onShare,
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 26,
                      shadows: [
                        Shadow(color: Colors.black38, blurRadius: 4),
                      ],
                    ),
                  ),

                // Send button (when focused)
                if (_isFocused)
                  GestureDetector(
                    onTap: () {
                      final val = _controller.text;
                      if (val.isNotEmpty) {
                        widget.onReply(val);
                        _controller.clear();
                        _focusNode.unfocus();
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: const Text(
                        'Send',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Owner footer ───────────────────────────────────
  Widget _buildOwnerFooter() {
    final story = widget.story;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Views count
            GestureDetector(
              onTap: _showViewers,
              child: Row(
                children: [
                  const Icon(
                    Icons.remove_red_eye_outlined,
                    color: Colors.white,
                    size: 22,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${story.viewCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),

            // More options
            GestureDetector(
              onTap: _showMoreOptions,
              child: const Icon(
                Icons.more_horiz,
                color: Colors.white,
                size: 26,
                shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showViewers() {
    // Show viewers bottom sheet
  }

  void _showMoreOptions() {
    // Show more options bottom sheet
  }
}

class _ReactionButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionButton({required this.emoji, required this.onTap});

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = Tween(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }
}
