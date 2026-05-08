// lib/features/chat/presentation/widgets/reaction_overlay.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:ui';
import '../../models/message.dart';
import '../../../../core/theme/chat_theme.dart';

class ReactionOverlay extends StatefulWidget {
  final ChatMessage message;
  final Animation<double> animation;
  final Function(String) onReact;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback? onUnsend;
  final VoidCallback onDelete;

  const ReactionOverlay({
    super.key,
    required this.message,
    required this.animation,
    required this.onReact,
    required this.onReply,
    required this.onCopy,
    required this.onForward,
    this.onUnsend,
    required this.onDelete,
  });

  @override
  State<ReactionOverlay> createState() =>
      _ReactionOverlayState();
}

class _ReactionOverlayState
    extends State<ReactionOverlay>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  int? _hovered;

  static const _emojis = [
    '❤️', '😂', '😮',
    '😢', '😡', '👏', '🔥',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 380),
    )..forward();

    _scale = CurvedAnimation(
        parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(
        parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        MediaQuery.of(context).platformBrightness ==
            Brightness.dark;
    final sw =
        MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Blurred backdrop
            BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: 12, sigmaY: 12),
              child: Container(
                color:
                    Colors.black.withOpacity(0.38),
              ),
            ),

            FadeTransition(
              opacity: _fade,
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                          horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ── EMOJI ROW
                      ScaleTransition(
                        scale: _scale,
                        child: Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                                  horizontal: 10,
                                  vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? ChatColors.darkCard
                                : Colors.white,
                            borderRadius:
                                BorderRadius.circular(
                                    40),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(
                                        0.22),
                                blurRadius: 28,
                                offset:
                                    const Offset(
                                        0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: _emojis
                                .asMap()
                                .entries
                                .map((e) {
                              final i = e.key;
                              final emoji = e.value;
                              final isH =
                                  _hovered == i;
                              final myReaction =
                                  widget.message
                                      .reactions
                                      .any((r) =>
                                          r.userId ==
                                              'me' &&
                                          r.emoji ==
                                              emoji);

                              return GestureDetector(
                                onTapDown: (_) {
                                  setState(() =>
                                      _hovered = i);
                                  HapticFeedback
                                      .selectionClick();
                                },
                                onTapUp: (_) {
                                  setState(() =>
                                      _hovered =
                                          null);
                                  Future.delayed(
                                    const Duration(
                                        milliseconds:
                                            80),
                                    () => widget
                                        .onReact(
                                            emoji),
                                  );
                                },
                                onTapCancel: () =>
                                    setState(() =>
                                        _hovered =
                                            null),
                                child:
                                    AnimatedContainer(
                                  duration:
                                      const Duration(
                                          milliseconds:
                                              150),
                                  curve: Curves
                                      .easeOutBack,
                                  width: isH
                                      ? 52
                                      : 40,
                                  height: isH
                                      ? 52
                                      : 40,
                                  margin:
                                      EdgeInsets
                                          .symmetric(
                                    horizontal:
                                        isH ? 3 : 1,
                                  ),
                                  decoration: myReaction
                                      ? BoxDecoration(
                                          shape:
                                              BoxShape
                                                  .circle,
                                          color: ChatColors
                                              .blue
                                              .withOpacity(
                                                  0.14),
                                        )
                                      : null,
                                  alignment:
                                      Alignment
                                          .center,
                                  child: Text(
                                    emoji,
                                    style:
                                        TextStyle(
                                      fontSize: isH
                                          ? 32
                                          : 24,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── MESSAGE PREVIEW
                      Container(
                        width: sw * 0.76,
                        padding:
                            const EdgeInsets.all(
                                14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? ChatColors.darkCard
                                  .withOpacity(0.92)
                              : Colors.white
                                  .withOpacity(
                                      0.92),
                          borderRadius:
                              BorderRadius.circular(
                                  16),
                        ),
                        child: _preview(isDark),
                      ),

                      const SizedBox(height: 10),

                      // ── OPTIONS LIST
                      Container(
                        width: sw * 0.76,
                        decoration: BoxDecoration(
                          color: isDark
                              ? ChatColors.darkCard
                              : Colors.white,
                          borderRadius:
                              BorderRadius.circular(
                                  16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(
                                      0.1),
                              blurRadius: 16,
                              offset:
                                  const Offset(
                                      0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _Option(
                              icon: LucideIcons
                                  .cornerUpLeft,
                              label: 'Reply',
                              isDark: isDark,
                              onTap: widget.onReply,
                            ),
                            _OptionDivider(
                                isDark: isDark),
                            if (widget.message
                                    .type ==
                                MessageType.text)
                              _Option(
                                icon:
                                    LucideIcons.copy,
                                label: 'Copy',
                                isDark: isDark,
                                onTap:
                                    widget.onCopy,
                              ),
                            if (widget.message
                                    .type ==
                                MessageType.text)
                              _OptionDivider(
                                  isDark: isDark),
                            _Option(
                              icon: LucideIcons
                                  .forward,
                              label: 'Forward',
                              isDark: isDark,
                              onTap:
                                  widget.onForward,
                            ),
                            if (widget.onUnsend !=
                                null) ...[
                              _OptionDivider(
                                  isDark: isDark),
                              _Option(
                                icon: LucideIcons
                                    .trash2,
                                label: 'Unsend',
                                isDark: isDark,
                                isDestructive: true,
                                onTap:
                                    widget.onUnsend!,
                              ),
                            ],
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(bool isDark) {
    final m = widget.message;
    switch (m.type) {
      case MessageType.image:
        return Row(
          children: [
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(8),
              child: Image.network(
                m.mediaUrl ?? '',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Photo',
              style: TextStyle(
                color: isDark
                    ? ChatColors.primaryDark
                    : ChatColors.primaryLight,
                fontSize: 14,
                fontFamily:
                    ChatTextStyles.fontFamily,
              ),
            ),
          ],
        );
      case MessageType.audio:
        return Row(
          children: [
            Icon(
              LucideIcons.mic,
              size: 18,
              color: ChatColors.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Voice message',
              style: TextStyle(
                color: ChatColors.secondary,
                fontSize: 14,
                fontFamily:
                    ChatTextStyles.fontFamily,
              ),
            ),
          ],
        );
      default:
        return Text(
          m.text ?? '',
          style: TextStyle(
            color: isDark
                ? ChatColors.primaryDark
                : ChatColors.primaryLight,
            fontSize: 15,
            fontFamily: ChatTextStyles.fontFamily,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

// ── Option Row ─────────────────────────────

class _Option extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool isDestructive;
  final VoidCallback onTap;

  const _Option({
    required this.icon,
    required this.label,
    required this.isDark,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? ChatColors.red
        : (isDark
            ? ChatColors.primaryDark
            : ChatColors.primaryLight);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        onTap();
      },
      child: SizedBox(
        height: 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontFamily:
                        ChatTextStyles.fontFamily,
                  ),
                ),
              ),
              Icon(icon, color: color, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionDivider extends StatelessWidget {
  final bool isDark;

  const _OptionDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.33,
      margin: const EdgeInsets.symmetric(
          horizontal: 16),
      color: isDark
          ? ChatColors.separatorDark
          : ChatColors.separatorLight,
    );
  }
}
