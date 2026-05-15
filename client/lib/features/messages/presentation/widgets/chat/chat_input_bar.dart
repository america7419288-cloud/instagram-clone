import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'chat_ui_constants.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String) onSend;
  final Function(String)? onChanged;
  final VoidCallback onLike;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onMicStart;
  final VoidCallback onMicStop;
  final VoidCallback onMicCancel;
  final bool isRecording;
  final Duration recordingDuration;
  final FocusNode? focusNode;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.onChanged,
    required this.onLike,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onMicStart,
    required this.onMicStop,
    required this.onMicCancel,
    this.isRecording = false,
    this.recordingDuration = Duration.zero,
    this.focusNode,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isRecording) {
      return AudioRecordingBar(
        duration: widget.recordingDuration,
        onCancel: widget.onMicCancel,
        onSend: widget.onMicStop,
      );
    }

    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? ChatUIConstants.bgDark : ChatUIConstants.bgLight;
    final separatorColor = isDark
        ? ChatUIConstants.separatorDark
        : ChatUIConstants.separatorLight;
    final inputBgColor = isDark
        ? ChatUIConstants.inputBgDark
        : ChatUIConstants.inputBgLight;

    return Container(
      padding: EdgeInsets.fromLTRB(
        10,
        7,
        10,
        7 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: separatorColor, width: 0.33)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left Icons (Camera, Gallery, Mic)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: _hasText
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      _buildIconButton(
                        LucideIcons.camera,
                        widget.onCameraTap,
                        filled: true,
                      ),
                      _buildIconButton(LucideIcons.image, widget.onGalleryTap),
                      _buildMicButton(),
                    ],
                  ),
          ),

          if (!_hasText) const SizedBox(width: 4),

          // Text Field Container
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 36, maxHeight: 116),
              decoration: BoxDecoration(
                color: inputBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFE3E3E3),
                  width: 0.6,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _controller,
                      focusNode: widget.focusNode,
                      onChanged: widget.onChanged,
                      placeholder: "Message...",
                      placeholderStyle: TextStyle(
                        fontFamily: ChatUIConstants.fontFamily,
                        fontSize: 15,
                        color: isDark
                            ? ChatUIConstants.textSecondaryDark
                            : ChatUIConstants.textSecondaryLight,
                        decoration: TextDecoration.none,
                      ),
                      style: TextStyle(
                        fontFamily: ChatUIConstants.fontFamily,
                        fontSize: 15,
                        color: isDark
                            ? ChatUIConstants.textPrimaryDark
                            : ChatUIConstants.textPrimaryLight,
                        decoration: TextDecoration.none,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: null,
                      maxLines: 5,
                      minLines: 1,
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.only(right: 4, bottom: 2),
                    minimumSize: const Size(34, 34),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                    },
                    child: Icon(
                      LucideIcons.smile,
                      size: 21,
                      color: isDark
                          ? ChatUIConstants.textPrimaryDark
                          : ChatUIConstants.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 7),

          // Right Button (Send or Like)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.elasticOut,
              ),
              child: child,
            ),
            child: _hasText ? _buildSendButton() : _buildLikeButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon,
    VoidCallback onTap, {
    bool filled = false,
  }) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final iconColor = filled
        ? CupertinoColors.white
        : (isDark
              ? ChatUIConstants.textPrimaryDark
              : ChatUIConstants.textPrimaryLight);

    return CupertinoButton(
      padding: const EdgeInsets.all(5),
      minimumSize: const Size(34, 34),
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? ChatUIConstants.verifiedBlue : null,
        ),
        child: Icon(icon, size: filled ? 17 : 23, color: iconColor),
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onLongPressStart: (_) {
        HapticFeedback.mediumImpact();
        widget.onMicStart();
      },
      onLongPressEnd: (_) {
        widget.onMicStop();
      },
      child: _buildIconButton(LucideIcons.mic, () {}),
    );
  }

  Widget _buildSendButton() {
    return CupertinoButton(
      key: const ValueKey('send_button'),
      padding: EdgeInsets.zero,
      onPressed: () {
        final text = _controller.text.trim();
        if (text.isNotEmpty) {
          HapticFeedback.lightImpact();
          widget.onSend(text);
          _controller.clear();
        }
      },
      child: Container(
        width: 35,
        height: 35,
        decoration: const BoxDecoration(
          color: ChatUIConstants.verifiedBlue,
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.send, size: 15, color: Color(0xFFFFFFFF)),
      ),
    );
  }

  Widget _buildLikeButton() {
    return LikeButton(key: const ValueKey('like_button'), onTap: widget.onLike);
  }
}

class LikeButton extends StatefulWidget {
  final VoidCallback onTap;
  const LikeButton({super.key, required this.onTap});

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 1.0,
              end: 1.45,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 40,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.45,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.elasticOut)),
            weight: 60,
          ),
        ]).animate(_controller),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            LucideIcons.heart,
            size: 28,
            color:
                (isDark
                        ? ChatUIConstants.textPrimaryDark
                        : ChatUIConstants.textPrimaryLight)
                    .withOpacity(0.85),
          ),
        ),
      ),
    );
  }
}

class AudioRecordingBar extends StatefulWidget {
  final Duration duration;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const AudioRecordingBar({
    super.key,
    required this.duration,
    required this.onCancel,
    required this.onSend,
  });

  @override
  State<AudioRecordingBar> createState() => _AudioRecordingBarState();
}

class _AudioRecordingBarState extends State<AudioRecordingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? ChatUIConstants.surfaceDark
        : ChatUIConstants.bgLight;

    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(
          top: BorderSide(color: ChatUIConstants.separatorLight, width: 0.33),
        ),
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              HapticFeedback.heavyImpact();
              widget.onCancel();
            },
            child: Row(
              children: [
                const Icon(
                  LucideIcons.x,
                  size: 16,
                  color: ChatUIConstants.textSecondaryLight,
                ),
                const SizedBox(width: 4),
                const Text(
                  "Cancel",
                  style: TextStyle(
                    fontFamily: ChatUIConstants.fontFamily,
                    fontSize: 15,
                    color: ChatUIConstants.textSecondaryLight,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          ScaleTransition(
            scale: Tween(begin: 0.6, end: 1.0).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: ChatUIConstants.likeRed,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(widget.duration),
            style: TextStyle(
              fontFamily: ChatUIConstants.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? ChatUIConstants.textPrimaryDark
                  : ChatUIConstants.textPrimaryLight,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onSend();
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: ChatUIConstants.verifiedBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.send,
                size: 18,
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
