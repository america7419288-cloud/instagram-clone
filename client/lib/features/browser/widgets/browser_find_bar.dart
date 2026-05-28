import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:instagram_client/core/theme/app_theme.dart';

class BrowserFindBar extends StatefulWidget {
  final Function(String) onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;
  final int matches;
  final int currentMatch;
  final bool isDark;

  const BrowserFindBar({
    super.key,
    required this.onChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    required this.matches,
    required this.currentMatch,
    required this.isDark,
  });

  @override
  State<BrowserFindBar> createState() => _BrowserFindBarState();
}

class _BrowserFindBarState extends State<BrowserFindBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF2F2F7),
        border: Border(
          bottom: BorderSide(
            color: isDark
              ? const Color(0xFF38383A)
              : const Color(0xFFE0E0E0),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark
                  ? const Color(0xFF2C2C2E)
                  : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.search,
                    size: 14,
                    color: isDark
                      ? Colors.white54
                      : Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14,
                        decoration: TextDecoration.none,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Find on page',
                        hintStyle: TextStyle(
                          color: isDark
                            ? Colors.white54
                            : Colors.black45,
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: widget.onChanged,
                    ),
                  ),

                  // Match counter
                  if (widget.matches > 0)
                    Text(
                      '${widget.currentMatch}/${widget.matches}',
                      style: TextStyle(
                        color: isDark
                          ? Colors.white54
                          : Colors.black45,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Previous
          _FindButton(
            icon: CupertinoIcons.chevron_up,
            enabled: widget.matches > 0,
            isDark: isDark,
            onTap: widget.onPrevious,
          ),

          // Next
          _FindButton(
            icon: CupertinoIcons.chevron_down,
            enabled: widget.matches > 0,
            isDark: isDark,
            onTap: widget.onNext,
          ),

          // Close
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: widget.onClose,
            child: const Text(
              'Done',
              style: TextStyle(
                color: AppColors.iosBlue,
                fontSize: 15,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FindButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool isDark;
  final VoidCallback onTap;

  const _FindButton({
    required this.icon,
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          icon,
          size: 20,
          color: enabled
            ? (isDark ? Colors.white : Colors.black)
            : (isDark ? Colors.white24 : Colors.black26),
        ),
      ),
    );
  }
}
