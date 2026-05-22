// lib/features/notes/widgets/audience_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/note_model.dart';

class AudienceSelector extends StatefulWidget {
  final NoteAudience initialAudience;
  final ValueChanged<NoteAudience> onAudienceChanged;

  const AudienceSelector({
    super.key,
    required this.initialAudience,
    required this.onAudienceChanged,
  });

  @override
  State<AudienceSelector> createState() => _AudienceSelectorState();
}

class _AudienceSelectorState extends State<AudienceSelector>
    with SingleTickerProviderStateMixin {
  late NoteAudience _selectedAudience;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedAudience = widget.initialAudience;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _slideAnimation = Tween<double>(
      begin: _selectedAudience == NoteAudience.followers ? -1.0 : 1.0,
      end: _selectedAudience == NoteAudience.followers ? -1.0 : 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onToggle(NoteAudience audience) {
    if (_selectedAudience == audience) return;

    HapticFeedback.selectionClick();
    setState(() {
      _selectedAudience = audience;
    });

    final double beginVal = _slideAnimation.value;
    final double endVal = audience == NoteAudience.followers ? -1.0 : 1.0;

    _slideAnimation = Tween<double>(begin: beginVal, end: endVal).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _animationController.forward(from: 0.0);
    widget.onAudienceChanged(audience);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.grey.withOpacity(0.12);

    final pillBg = isDark
        ? const Color(0xFF3A3A3C)
        : Colors.white;

    final activeTextColor = isDark ? Colors.white : Colors.black;
    final inactiveTextColor = isDark ? Colors.grey[500] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      height: 38,
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // 1. Sliding pill background
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Align(
                alignment: Alignment(_slideAnimation.value, 0.0),
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Container(
                    margin: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // 2. Clickable segments text overlays
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _onToggle(NoteAudience.followers),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '👥',
                          style: TextStyle(
                            fontSize: 11,
                            opacity: _selectedAudience == NoteAudience.followers ? 1.0 : 0.6,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Followers',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _selectedAudience == NoteAudience.followers
                                ? activeTextColor
                                : inactiveTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _onToggle(NoteAudience.closeFriends),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '💚',
                          style: TextStyle(
                            fontSize: 11,
                            opacity: _selectedAudience == NoteAudience.closeFriends ? 1.0 : 0.6,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Close Friends',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _selectedAudience == NoteAudience.closeFriends
                                ? activeTextColor
                                : inactiveTextColor,
                          ),
                        ),
                      ],
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
