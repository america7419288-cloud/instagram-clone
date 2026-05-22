// lib/features/notes/pages/note_view_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/notes_controller.dart';
import '../models/note_model.dart';
import '../widgets/note_bubble.dart';

class NoteViewSheet extends ConsumerStatefulWidget {
  final NoteModel note;

  const NoteViewSheet({
    super.key,
    required this.note,
  });

  static Future<void> show(BuildContext context, NoteModel note) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => NoteViewSheet(note: note),
    );
  }

  @override
  ConsumerState<NoteViewSheet> createState() => _NoteViewSheetState();
}

class _NoteViewSheetState extends ConsumerState<NoteViewSheet>
    with TickerProviderStateMixin {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  bool _isSending = false;
  String _inputText = '';

  // Emojis list
  final List<String> _emojis = ['😂', '❤️', '🔥', '👏', '😮', '🙌'];

  // Individual Emoji bounce animation controllers
  late List<AnimationController> _emojiControllers;
  late List<Animation<double>> _emojiScales;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();

    _textController.addListener(() {
      setState(() {
        _inputText = _textController.text;
      });
    });

    // Setup bounce animators for each emoji
    _emojiControllers = List.generate(
      _emojis.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );

    _emojiScales = _emojiControllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.45)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.45, end: 0.9)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 35,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.9, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 25,
        ),
      ]).animate(controller);
    }).toList();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    for (var controller in _emojiControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleEmojiReaction(int index) async {
    final emoji = _emojis[index];
    HapticFeedback.mediumImpact();

    // Trigger local scale bounce animation
    await _emojiControllers[index].forward(from: 0.0);

    setState(() {
      _isSending = true;
    });

    // Send the reply message
    await ref.read(notesProvider.notifier).replyToNote(widget.note, emoji);

    if (mounted) {
      Navigator.pop(context);
      _showReplySuccessSnackBar(emoji);
    }
  }

  Future<void> _handleTextReply() async {
    final reply = _textController.text.trim();
    if (reply.isEmpty || _isSending) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSending = true;
    });

    await ref.read(notesProvider.notifier).replyToNote(widget.note, reply);

    if (mounted) {
      Navigator.pop(context);
      _showReplySuccessSnackBar(reply);
    }
  }

  void _showReplySuccessSnackBar(String reply) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('✉️ ', style: TextStyle(fontSize: 16)),
            Expanded(
              child: Text(
                'Sent reply to ${widget.note.username}: "$reply"',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF262626),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardActive = keyboardHeight > 0;

    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(bottom: keyboardHeight + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // DRAG HANDLE
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Main Note representation card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // LARGED NOTE BUBBLE
                  NoteBubble(
                    note: widget.note,
                    isLarge: true,
                    animateEntry: true,
                  ),
                  const SizedBox(height: 14),

                  // USER AVATAR WITH OVERLAYS
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: isDark ? Colors.grey[850] : Colors.grey[200],
                        backgroundImage: widget.note.avatarUrl.isNotEmpty
                            ? NetworkImage(widget.note.avatarUrl)
                            : null,
                        child: widget.note.avatarUrl.isEmpty
                            ? Icon(Icons.person,
                                size: 38,
                                color: isDark ? Colors.white54 : Colors.black38)
                            : null,
                      ),
                      // Small indicator showing if they are Close Friends
                      if (widget.note.audience == NoteAudience.closeFriends)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF17C37B), // Close friends green
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: bgColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // USERNAME & METADATA
                  Text(
                    widget.note.username,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      fontFamily: 'SF Pro Text',
                    ),
                  ),
                  const SizedBox(height: 4),

                  // EXPIRED COUNTER
                  Text(
                    '${widget.note.postedAgoText} • Expires in ${widget.note.timeRemainingText}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontFamily: 'SF Pro Text',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(height: 0.5, thickness: 0.5),

            // QUICK EMOJI REACTION TOOLBAR
            if (!isKeyboardActive) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_emojis.length, (index) {
                    return GestureDetector(
                      onTap: _isSending ? null : () => _handleEmojiReaction(index),
                      behavior: HitTestBehavior.opaque,
                      child: ScaleTransition(
                        scale: _emojiScales[index],
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            _emojis[index],
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const Divider(height: 0.5, thickness: 0.5),
            ],

            // STANDARD REPLY INPUT BAR
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.2),
                          width: 0.8,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Send message...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                            fontSize: 14.5,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleTextReply(),
                      ),
                    ),
                  ),

                  // ANIMATED SLIDE-IN / FADE-IN SEND BUTTON
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: _inputText.trim().isNotEmpty
                        ? GestureDetector(
                            onTap: _isSending ? null : _handleTextReply,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Text(
                                _isSending ? 'Sending' : 'Send',
                                style: const TextStyle(
                                  color: Color(0xFF0095F6),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
