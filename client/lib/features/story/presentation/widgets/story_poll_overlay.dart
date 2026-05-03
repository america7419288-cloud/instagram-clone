// lib/features/story/presentation/widgets/story_poll_overlay.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/story_advanced_model.dart';

class StoryPollOverlay extends StatefulWidget {
  final StoryPollModel poll;
  final void Function(String option) onVote;
  final bool isOwner;

  const StoryPollOverlay({
    super.key,
    required this.poll,
    required this.onVote,
    this.isOwner = false,
  });

  @override
  State<StoryPollOverlay> createState() => _StoryPollOverlayState();
}

class _StoryPollOverlayState extends State<StoryPollOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _barController;
  late Animation<double>   _barA;
  late Animation<double>   _barB;

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );

    final pA = widget.poll.percentA / 100.0;
    final pB = widget.poll.percentB / 100.0;

    _barA = Tween<double>(begin: 0, end: pA).animate(
      CurvedAnimation(parent: _barController, curve: Curves.easeOut),
    );
    _barB = Tween<double>(begin: 0, end: pB).animate(
      CurvedAnimation(parent: _barController, curve: Curves.easeOut),
    );

    if (widget.poll.hasVoted || widget.isOwner) {
      _barController.forward();
    }
  }

  @override
  void dispose() {
    _barController.dispose();
    super.dispose();
  }

  void _vote(String option) {
    if (widget.poll.hasVoted) return;
    HapticFeedback.mediumImpact();
    widget.onVote(option);
    _barController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final showResults = widget.poll.hasVoted || widget.isOwner;

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
          // ─── Question ────────────────────────────────
          Text(
            widget.poll.question,
            style: const TextStyle(
              color:      Colors.black,
              fontSize:   15,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // ─── Options ─────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _PollButton(
                  label:       widget.poll.optionA,
                  percent:     widget.poll.percentA,
                  isSelected:  widget.poll.myVote == 'a',
                  showResults: showResults,
                  barAnim:     _barA,
                  color:       Colors.blue,
                  onTap:       () => _vote('a'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PollButton(
                  label:       widget.poll.optionB,
                  percent:     widget.poll.percentB,
                  isSelected:  widget.poll.myVote == 'b',
                  showResults: showResults,
                  barAnim:     _barB,
                  color:       Colors.pink,
                  onTap:       () => _vote('b'),
                ),
              ),
            ],
          ),

          // ─── Total votes ──────────────────────────────
          if (showResults) ...[
            const SizedBox(height: 8),
            Text(
              '${widget.poll.totalVotes} votes',
              style: const TextStyle(
                color:    Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PollButton extends StatelessWidget {
  final String            label;
  final int               percent;
  final bool              isSelected;
  final bool              showResults;
  final Animation<double> barAnim;
  final Color             color;
  final VoidCallback      onTap;

  const _PollButton({
    required this.label,
    required this.percent,
    required this.isSelected,
    required this.showResults,
    required this.barAnim,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!showResults) {
      // ─── Voting button ─────────────────────────────
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: color, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:      color,
              fontSize:   14,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines:  1,
            overflow:  TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // ─── Results bar ─────────────────────────────────
    return AnimatedBuilder(
      animation: barAnim,
      builder: (_, __) {
        return Container(
          height:      56,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              // Progress fill
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: barAnim.value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color:        color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Label + percent
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    if (isSelected)
                      Icon(Icons.check_circle, color: color, size: 16),
                    if (isSelected) const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color:      isSelected ? color : Colors.black87,
                          fontSize:   13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color:      isSelected ? color : Colors.grey,
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}