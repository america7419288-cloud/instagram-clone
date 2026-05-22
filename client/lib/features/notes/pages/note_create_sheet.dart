// lib/features/notes/pages/note_create_sheet.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../controllers/notes_controller.dart';
import '../models/note_model.dart';
import '../widgets/note_bubble.dart';
import '../widgets/audience_selector.dart';

class NoteCreateSheet extends ConsumerStatefulWidget {
  final NoteModel? existingNote; // null = new note

  const NoteCreateSheet({
    super.key,
    this.existingNote,
  });

  static Future<void> show(BuildContext context, {NoteModel? existingNote}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => NoteCreateSheet(existingNote: existingNote),
    );
  }

  @override
  ConsumerState<NoteCreateSheet> createState() => _NoteCreateSheetState();
}

class _NoteCreateSheetState extends ConsumerState<NoteCreateSheet>
    with TickerProviderStateMixin {
  late TextEditingController _textController;
  late FocusNode _focusNode;

  // Pulse & Shake Animation Controllers
  late AnimationController _previewPulseController;
  late Animation<double> _previewScale;

  late AnimationController _shakeController;
  late Animation<double> _shakeTranslation;

  NoteAudience _selectedAudience = NoteAudience.followers;
  bool _isSharing = false;
  String _previewText = '';
  int _lastCharCount = 0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _textController = TextEditingController(
      text: widget.existingNote?.text ?? '',
    );
    _previewText = _textController.text;
    _lastCharCount = _previewText.length;
    _selectedAudience = widget.existingNote?.audience ?? NoteAudience.followers;

    // 1. Setup Preview Pulse Animation
    _previewPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _previewScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_previewPulseController);

    // 2. Setup Shake Animation (translateX: 0 -> 4 -> -4 -> 2 -> -2 -> 0)
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _shakeTranslation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 5.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: -5.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 3.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 3.0, end: -2.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -2.0, end: 0.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));

    _textController.addListener(_onTextChanged);

    // Auto-focus input delayed to prevent keyboard pop overlap jarring sheets slide-up
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _previewPulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final newText = _textController.text;
    final currentCount = newText.length;

    if (newText != _previewText) {
      setState(() {
        _previewText = newText;
      });

      // Pulse the preview bubble on every keystroke
      _previewPulseController.forward(from: 0.0);

      // Trigger shake when reaching the warning thresholds or exactly the limit
      if (currentCount >= 55 && _lastCharCount < 55) {
        _shakeController.forward(from: 0.0);
        HapticFeedback.warningImpact();
      } else if (currentCount == 60 && _lastCharCount < 60) {
        _shakeController.forward(from: 0.0);
        HapticFeedback.vibrate();
      }

      _lastCharCount = currentCount;
    }
  }

  Future<void> _shareNote() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSharing = true;
    });

    // Simulate small backend upload latency
    await Future.delayed(const Duration(milliseconds: 300));

    ref.read(notesProvider.notifier).shareNote(text, _selectedAudience);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('💭 ', style: TextStyle(fontSize: 15)),
              Text(
                widget.existingNote != null ? 'Note updated successfully' : 'Note shared successfully',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF262626),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _deleteNote() {
    HapticFeedback.mediumImpact();
    ref.read(notesProvider.notifier).deleteNote();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final currentUser = ref.watch(currentUserProvider);
    final avatarUrl = currentUser?.profilePicUrl ?? '';
    final username = currentUser?.username ?? 'your_username';

    final hasText = _previewText.isNotEmpty;
    final charCount = _textController.text.length;

    return WillPopScope(
      onWillPop: () async => !_isSharing,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // DRAG HANDLE
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // TITLE ACTION BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    widget.existingNote != null ? 'Edit note' : 'New note',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                      fontFamily: 'SF Pro Text',
                    ),
                  ),
                  Positioned(
                    left: 0,
                    child: GestureDetector(
                      onTap: _isSharing ? null : () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      onTap: (hasText && !_isSharing) ? _shareNote : null,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: hasText
                              ? const Color(0xFF0095F6)
                              : (isDark ? Colors.grey[700] : Colors.grey[300]),
                        ),
                        child: Text(_isSharing ? 'Sharing...' : 'Share'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // LIVE PREVIEW BUBBLE OVER AVATAR
            AnimatedBuilder(
              animation: _previewPulseController,
              builder: (_, child) => Transform.scale(
                scale: _previewScale.value,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Speech bubble preview
                  hasText
                      ? NoteBubble(
                          note: NoteModel(
                            id: 'preview',
                            userId: 'me',
                            username: 'me',
                            avatarUrl: '',
                            text: _previewText,
                            createdAt: DateTime.now(),
                            audience: _selectedAudience,
                            isOwn: true,
                          ),
                          isPreview: true,
                        )
                      : _buildPlaceholderBubble(isDark),

                  const SizedBox(height: 8),

                  // Your profile avatar
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: isDark ? Colors.grey[850] : Colors.grey[200],
                        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isEmpty ? Icon(Icons.person, color: isDark ? Colors.white54 : Colors.black38, size: 30) : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0095F6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Username label
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // SEGMENTED AUDIENCE SELECTOR
            AudienceSelector(
              initialAudience: _selectedAudience,
              onAudienceChanged: (val) {
                setState(() {
                  _selectedAudience = val;
                });
              },
            ),

            const SizedBox(height: 16),

            // TEXT INPUT RECTANGLE (Dim background with shake transitions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeTranslation.value, 0.0),
                    child: child,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLength: 60,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.5,
                      color: isDark ? Colors.white : Colors.black,
                      fontFamily: 'SF Pro Text',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Share a thought...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                      counterText: '', // Hide native counter
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _shareNote(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // TOOL BAR & CHARACTER COUNTER ROW
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Shake-integrated Character limit text
                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeTranslation.value * 0.7, 0.0),
                        child: child,
                      );
                    },
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 150),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: charCount > 55 ? FontWeight.w700 : FontWeight.w400,
                        color: charCount > 55
                            ? (charCount >= 60 ? Colors.red : Colors.orange)
                            : (isDark ? Colors.grey[500] : Colors.grey[400]),
                      ),
                      child: Text('$charCount/60'),
                    ),
                  ),

                  const Spacer(),

                  // Quick tools row
                  _buildToolIcon(
                    Icons.emoji_emotions_outlined,
                    () {
                      // Trigger native emojis or input insertion
                    },
                    isDark,
                  ),
                  const SizedBox(width: 14),
                  _buildToolIcon(
                    Icons.music_note_outlined,
                    () {
                      // Music selection mockup
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Music search details appear here.')),
                      );
                    },
                    isDark,
                  ),
                  const SizedBox(width: 14),
                  // Custom styled GIF badge button
                  GestureDetector(
                    onTap: () {
                      // GIF search mockup
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'GIF',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // If editing an existing note, show explicit delete button at the very bottom
            if (widget.existingNote != null) ...[
              const SizedBox(height: 18),
              const Divider(height: 0.5, thickness: 0.5),
              GestureDetector(
                onTap: _deleteNote,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  child: const Text(
                    'Delete Note',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderBubble(bool isDark) {
    final bubbleColor = isDark ? const Color(0xFF2C2C2E) : Colors.grey[100];
    final borderColor = isDark ? const Color(0xFF3A3A3C) : Colors.grey[300];

    return Container(
      constraints: const BoxConstraints(minWidth: 60, maxWidth: 130),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
          bottomLeft: Radius.circular(4),
        ),
        border: Border.all(color: borderColor!, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Text(
        'Share a thought...',
        style: TextStyle(
          fontSize: 10.5,
          color: isDark ? Colors.grey[500] : Colors.grey[400],
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildToolIcon(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(
        icon,
        size: 22,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
    );
  }
}
