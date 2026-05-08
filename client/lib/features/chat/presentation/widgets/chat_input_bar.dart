// lib/features/chat/presentation/widgets/chat_input_bar.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/chat_theme.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final bool isComposing;
  final bool isRecording;
  final Duration recordingDuration;
  final bool isDark;
  final VoidCallback onSend;
  final VoidCallback onSendLike;
  final VoidCallback onStartRecord;
  final Future<void> Function() onStopRecord;
  final VoidCallback onCancelRecord;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  const ChatInputBar({
    super.key,
    required this.textController,
    required this.focusNode,
    required this.isComposing,
    required this.isRecording,
    required this.recordingDuration,
    required this.isDark,
    required this.onSend,
    required this.onSendLike,
    required this.onStartRecord,
    required this.onStopRecord,
    required this.onCancelRecord,
    required this.onGallery,
    required this.onCamera,
  });

  @override
  State<ChatInputBar> createState() =>
      _ChatInputBarState();
}

class _ChatInputBarState
    extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {

  late AnimationController _sendSwitchCtrl;

  @override
  void initState() {
    super.initState();
    _sendSwitchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    if (widget.isComposing) _sendSwitchCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(ChatInputBar old) {
    super.didUpdateWidget(old);
    if (old.isComposing != widget.isComposing) {
      widget.isComposing
          ? _sendSwitchCtrl.forward()
          : _sendSwitchCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.of(context).padding.bottom;
    final isDark = widget.isDark;

    if (widget.isRecording) {
      return _RecordingBar(
        duration: widget.recordingDuration,
        isDark: isDark,
        bottomPad: bottom,
        onStop: widget.onStopRecord,
        onCancel: widget.onCancelRecord,
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + bottom),
      decoration: BoxDecoration(
        color: isDark
            ? ChatColors.black
            : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? ChatColors.separatorDark
                : ChatColors.separatorLight,
            width: 0.33,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [

          // Left icons (hidden when composing)
          AnimatedSize(
            duration:
                const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: !widget.isComposing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _InputBtn(
                        icon: LucideIcons.camera,
                        isDark: isDark,
                        onTap: widget.onCamera,
                      ),
                      _InputBtn(
                        icon: LucideIcons.image,
                        isDark: isDark,
                        onTap: widget.onGallery,
                      ),
                      _MicBtn(
                        isDark: isDark,
                        onLongPressStart: (_) =>
                            widget.onStartRecord(),
                        onLongPressEnd: (_) =>
                            widget.onStopRecord(),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight:
                    ChatDimens.inputHeight,
                maxHeight:
                    ChatDimens.inputMaxHeight,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? ChatColors.darkCard
                    : const Color(0xFFEFEFEF),
                borderRadius:
                    BorderRadius.circular(
                        ChatDimens.inputRadius),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller:
                          widget.textController,
                      focusNode: widget.focusNode,
                      placeholder: 'Message...',
                      placeholderStyle: const TextStyle(
                        color: ChatColors.secondary,
                        fontSize: 15,
                        fontFamily:
                            ChatTextStyles.fontFamily,
                      ),
                      style: TextStyle(
                        color: isDark
                            ? ChatColors.primaryDark
                            : ChatColors.primaryLight,
                        fontSize: 15,
                        fontFamily:
                            ChatTextStyles.fontFamily,
                      ),
                      maxLines: null,
                      keyboardType:
                          TextInputType.multiline,
                      textInputAction:
                          TextInputAction.newline,
                      decoration: null,
                      padding:
                          const EdgeInsets.fromLTRB(
                              14, 9, 6, 9),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                            0, 0, 4, 5),
                    child: _InputBtn(
                      icon: LucideIcons.smile,
                      isDark: isDark,
                      size: 21,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 7),

          // Send / Like button
          AnimatedSwitcher(
            duration:
                const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) =>
                ScaleTransition(
              scale: CurvedAnimation(
                parent: anim,
                curve: Curves.elasticOut,
              ),
              child: child,
            ),
            child: widget.isComposing
                ? _SendBtn(
                    key: const ValueKey('send'),
                    onTap: widget.onSend,
                  )
                : _LikeBtn(
                    key: const ValueKey('like'),
                    isDark: isDark,
                    onTap: widget.onSendLike,
                  ),
          ),

        ],
      ),
    );
  }

  @override
  void dispose() {
    _sendSwitchCtrl.dispose();
    super.dispose();
  }
}

// ── Buttons ────────────────────────────────

class _InputBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final double size;
  final VoidCallback onTap;

  const _InputBtn({
    required this.icon,
    required this.isDark,
    this.size = 25,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.all(7),
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Icon(
        icon,
        size: size,
        color: isDark
            ? Colors.white.withOpacity(0.85)
            : ChatColors.primaryLight,
      ),
    );
  }
}

class _MicBtn extends StatelessWidget {
  final bool isDark;
  final Function(LongPressStartDetails)
      onLongPressStart;
  final Function(LongPressEndDetails)
      onLongPressEnd;

  const _MicBtn({
    required this.isDark,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (d) {
        HapticFeedback.mediumImpact();
        onLongPressStart(d);
      },
      onLongPressEnd: onLongPressEnd,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(
          LucideIcons.mic,
          size: 25,
          color: isDark
              ? Colors.white.withOpacity(0.85)
              : ChatColors.primaryLight,
        ),
      ),
    );
  }
}

class _SendBtn extends StatelessWidget {
  final VoidCallback onTap;

  const _SendBtn({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 35,
        height: 35,
        decoration: const BoxDecoration(
          color: ChatColors.blue,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          LucideIcons.send,
          color: Colors.white,
          size: 15,
        ),
      ),
    );
  }
}

class _LikeBtn extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _LikeBtn({
    super.key,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_LikeBtn> createState() =>
      _LikeBtnState();
}

class _LikeBtnState extends State<_LikeBtn>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 380),
    );
    _scale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.45)
            .chain(CurveTween(
                curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.45, end: 1.0)
            .chain(CurveTween(
                curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_ctrl);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _ctrl
          ..reset()
          ..forward();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            LucideIcons.heart,
            size: 28,
            color: widget.isDark
                ? Colors.white.withOpacity(0.85)
                : ChatColors.primaryLight,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// RECORDING BAR
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _RecordingBar extends StatefulWidget {
  final Duration duration;
  final bool isDark;
  final double bottomPad;
  final Future<void> Function() onStop;
  final VoidCallback onCancel;

  const _RecordingBar({
    required this.duration,
    required this.isDark,
    required this.bottomPad,
    required this.onStop,
    required this.onCancel,
  });

  @override
  State<_RecordingBar> createState() =>
      _RecordingBarState();
}

class _RecordingBarState
    extends State<_RecordingBar>
    with SingleTickerProviderStateMixin {

  late AnimationController _pulse;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _pulseScale = Tween(begin: 0.75, end: 1.0)
        .animate(CurvedAnimation(
            parent: _pulse,
            curve: Curves.easeInOut));
  }

  String _fmt(Duration d) {
    final m =
        d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60)
        .toString()
        .padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + widget.bottomPad),
      decoration: BoxDecoration(
        color: widget.isDark
            ? ChatColors.black
            : Colors.white,
        border: Border(
          top: BorderSide(
            color: widget.isDark
                ? ChatColors.separatorDark
                : ChatColors.separatorLight,
            width: 0.33,
          ),
        ),
      ),
      child: Row(
        children: [
          // Cancel
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: widget.onCancel,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.x,
                  size: 16,
                  color: ChatColors.secondary,
                ),
                const SizedBox(width: 3),
                Text(
                  'Cancel',
                  style: TextStyle(
                    color: ChatColors.secondary,
                    fontSize: 15,
                    fontFamily:
                        ChatTextStyles.fontFamily,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Pulsing dot + timer
          Row(
            children: [
              ScaleTransition(
                scale: _pulseScale,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: ChatColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmt(widget.duration),
                style: TextStyle(
                  color: widget.isDark
                      ? ChatColors.primaryDark
                      : ChatColors.primaryLight,
                  fontSize: 16,
                  fontFamily:
                      ChatTextStyles.fontFamily,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Send
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: widget.onStop,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: ChatColors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.send,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }
}
