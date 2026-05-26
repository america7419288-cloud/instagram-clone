import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/theme/app_theme.dart';

enum DisappearingDuration {
  off('Off', null),
  twentyFourHours('24 hours', Duration(hours: 24)),
  sevenDays('7 days', Duration(days: 7)),
  ninetyDays('90 days', Duration(days: 90));

  final String label;
  final Duration? duration;

  const DisappearingDuration(this.label, this.duration);
}

class DisappearingMessageDialog extends StatefulWidget {
  final DisappearingDuration currentDuration;
  final Function(DisappearingDuration) onChanged;

  const DisappearingMessageDialog({
    super.key,
    required this.currentDuration,
    required this.onChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required DisappearingDuration currentDuration,
    required Function(DisappearingDuration) onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DisappearingMessageDialog(
        currentDuration: currentDuration,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<DisappearingMessageDialog> createState() => _DisappearingMessageDialogState();
}

class _DisappearingMessageDialogState extends State<DisappearingMessageDialog> {
  late DisappearingDuration _selectedDuration;

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.currentDuration;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white60 : Colors.black45;
    final bgColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.94);
    final separatorColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.07);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.62,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      Text(
                        'Disappearing Messages',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'SF Pro Display',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: () {
                          widget.onChanged(_selectedDuration);
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Done',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 0.5, thickness: 0.5, color: separatorColor),

                // Icon + description
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.timer,
                          size: 26,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-delete messages',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                                fontFamily: 'SF Pro Display',
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Messages disappear automatically after the set time.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: textSecondary,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 0.5, thickness: 0.5, color: separatorColor),

                // Options list
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: DisappearingDuration.values.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: separatorColor,
                      indent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final duration = DisappearingDuration.values[index];
                      final isSelected = _selectedDuration == duration;

                      return _DurationOption(
                        duration: duration,
                        isSelected: isSelected,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onTap: () {
                          setState(() {
                            _selectedDuration = duration;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationOption extends StatefulWidget {
  final DisappearingDuration duration;
  final bool isSelected;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _DurationOption({
    required this.duration,
    required this.isSelected,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  State<_DurationOption> createState() => _DurationOptionState();
}

class _DurationOptionState extends State<_DurationOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pressColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        color: _pressed ? pressColor : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.duration.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: widget.textPrimary,
                      fontFamily: 'SF Pro Display',
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (widget.duration == DisappearingDuration.off) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Messages won\'t disappear',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: widget.textSecondary,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: widget.isSelected
                  ? const Icon(
                      LucideIcons.check,
                      color: AppColors.primary,
                      size: 22,
                      key: ValueKey('check'),
                    )
                  : const SizedBox(width: 22, key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }
}
