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
    return showCupertinoModalPopup(
      context: context,
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
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                    ),
                  ),
                ),
                const Text(
                  'Disappearing Messages',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    widget.onChanged(_selectedDuration);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Icon and Description
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.timer,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Set messages to automatically disappear',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how long messages stay visible after they\'re sent',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Options
          Expanded(
            child: ListView.builder(
              itemCount: DisappearingDuration.values.length,
              itemBuilder: (context, index) {
                final duration = DisappearingDuration.values[index];
                final isSelected = _selectedDuration == duration;

                return _DurationOption(
                  duration: duration,
                  isSelected: isSelected,
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
    );
  }
}

class _DurationOption extends StatelessWidget {
  final DisappearingDuration duration;
  final bool isSelected;
  final VoidCallback onTap;

  const _DurationOption({
    required this.duration,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    duration.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (duration == DisappearingDuration.off)
                    Text(
                      'Messages won\'t disappear',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                LucideIcons.check,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
