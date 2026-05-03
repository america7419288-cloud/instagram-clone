// lib/features/story/presentation/widgets/story_question_overlay.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/story_advanced_model.dart';

class StoryQuestionOverlay extends StatefulWidget {
  final StoryQuestionModel  question;
  final void Function(String answer) onAnswer;
  final bool isOwner;

  const StoryQuestionOverlay({
    super.key,
    required this.question,
    required this.onAnswer,
    this.isOwner = false,
  });

  @override
  State<StoryQuestionOverlay> createState() =>
      _StoryQuestionOverlayState();
}

class _StoryQuestionOverlayState extends State<StoryQuestionOverlay> {
  final TextEditingController _ctrl    = TextEditingController();
  bool                        _sent    = false;
  bool                        _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty || _sending) return;
    HapticFeedback.lightImpact();
    setState(() => _sending = true);
    widget.onAnswer(_ctrl.text.trim());
    setState(() {
      _sent    = true;
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Question mark icon ───────────────────────
          Container(
            width:  36,
            height: 36,
            decoration: BoxDecoration(
              color:  Colors.blue.withOpacity(0.12),
              shape:  BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline,
              color: Colors.blue,
              size:  20,
            ),
          ),
          const SizedBox(height: 8),

          // ─── Question text ────────────────────────────
          Text(
            widget.question.question,
            style: const TextStyle(
              color:      Colors.black,
              fontSize:   15,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // ─── Owner view vs answerer view ──────────────
          if (widget.isOwner)
            Text(
              '${widget.question.answersCount} answers',
              style: const TextStyle(
                color:    Colors.grey,
                fontSize: 13,
              ),
            )
          else if (_sent)
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(height: 4),
                Text(
                  'Answer sent!',
                  style: TextStyle(
                    color:      Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller:    _ctrl,
                  maxLines:      3,
                  minLines:      1,
                  maxLength:     500,
                  decoration: InputDecoration(
                    hintText:    'Write your answer...',
                    filled:      true,
                    fillColor:   Colors.grey.shade100,
                    border:      OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:   BorderSide.none,
                    ),
                    counterStyle: const TextStyle(
                      fontSize: 10,
                      color:    Colors.grey,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color:    Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape:           RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width:  18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color:       Colors.white,
                            ),
                          )
                        : const Text(
                            'Send Answer',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}