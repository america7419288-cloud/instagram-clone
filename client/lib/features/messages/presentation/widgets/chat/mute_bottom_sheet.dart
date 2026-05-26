// lib/features/messages/presentation/widgets/chat/mute_bottom_sheet.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class MuteBottomSheet extends StatelessWidget {
  final String username;
  final ValueChanged<String> onMuteSelected;

  const MuteBottomSheet({
    super.key,
    required this.username,
    required this.onMuteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Map<String, String> options = {
      '1 Hour': '1h',
      '8 Hours': '8h',
      '24 Hours': '24h',
      '1 Week': '1week',
      'Until I turn it back on': 'forever',
    };

    final bgColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
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
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Bell icon + Header
                  Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.bell_off,
                      size: 22,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Mute notifications for $username?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                        fontFamily: 'SF Pro Display',
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      "You won't get notifications for new messages during this period.",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Options
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: options.entries.toList().asMap().entries.map((entry) {
                        final i = entry.key;
                        final label = entry.value.key;
                        final value = entry.value.value;
                        final isLast = i == options.length - 1;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MuteOptionTile(
                              label: label,
                              isDark: isDark,
                              onTap: () => onMuteSelected(value),
                            ),
                            if (!isLast)
                              Divider(
                                height: 0.5,
                                thickness: 0.5,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                                indent: 16,
                                endIndent: 0,
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Cancel button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                          fontFamily: 'SF Pro Display',
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MuteOptionTile extends StatefulWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _MuteOptionTile({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MuteOptionTile> createState() => _MuteOptionTileState();
}

class _MuteOptionTileState extends State<_MuteOptionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pressColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.07)
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w400,
                color: widget.isDark ? Colors.white : const Color(0xFF1C1C1E),
                fontFamily: 'SF Pro Display',
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
