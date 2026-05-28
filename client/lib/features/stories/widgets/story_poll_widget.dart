import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/story_model.dart';

class StoryPollWidget extends StatefulWidget {
  final StoryPollData poll;
  final bool isOwner;
  final Function(int option)? onVote;

  const StoryPollWidget({
    super.key,
    required this.poll,
    this.isOwner = false,
    this.onVote,
  });

  @override
  State<StoryPollWidget> createState() => _StoryPollWidgetState();
}

class _StoryPollWidgetState extends State<StoryPollWidget>
    with TickerProviderStateMixin {
  int? _votedOption;
  late AnimationController _bar1Controller;
  late AnimationController _bar2Controller;
  late Animation<double> _bar1Anim;
  late Animation<double> _bar2Anim;

  @override
  void initState() {
    super.initState();
    _votedOption = widget.poll.myVote;

    _bar1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bar2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _bar1Anim = CurvedAnimation(
      parent: _bar1Controller,
      curve: Curves.fastOutSlowIn,
    );
    _bar2Anim = CurvedAnimation(
      parent: _bar2Controller,
      curve: Curves.fastOutSlowIn,
    );

    if (_votedOption != null || widget.isOwner) {
      _bar1Controller.value = widget.poll.percent1;
      _bar2Controller.value = widget.poll.percent2;
    }
  }

  @override
  void dispose() {
    _bar1Controller.dispose();
    _bar2Controller.dispose();
    super.dispose();
  }

  void _vote(int option) {
    if (_votedOption != null || widget.isOwner) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _votedOption = option;
    });

    // Animate bars
    _bar1Controller.animateTo(
      option == 1
          ? (widget.poll.votes1 + 1) / (widget.poll.totalVotes + 1)
          : widget.poll.votes1 / (widget.poll.totalVotes + 1),
    );
    _bar2Controller.animateTo(
      option == 2
          ? (widget.poll.votes2 + 1) / (widget.poll.totalVotes + 1)
          : widget.poll.votes2 / (widget.poll.totalVotes + 1),
    );

    widget.onVote?.call(option);
  }

  @override
  Widget build(BuildContext context) {
    final hasVoted = _votedOption != null || widget.isOwner;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Question Icon/Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF58529)],
                    ),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'POLL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFD1D1D),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Question text
            Text(
              widget.poll.question,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Options row
            Row(
              children: [
                Expanded(
                  child: _PollOptionButton(
                    label: widget.poll.option1,
                    percent: widget.poll.percent1,
                    percentAnim: _bar1Anim,
                    isSelected: _votedOption == 1,
                    isWinner: hasVoted && widget.poll.percent1 >= widget.poll.percent2,
                    hasVoted: hasVoted,
                    onTap: () => _vote(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PollOptionButton(
                    label: widget.poll.option2,
                    percent: widget.poll.percent2,
                    percentAnim: _bar2Anim,
                    isSelected: _votedOption == 2,
                    isWinner: hasVoted && widget.poll.percent2 > widget.poll.percent1,
                    hasVoted: hasVoted,
                    onTap: () => _vote(2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PollOptionButton extends StatelessWidget {
  final String label;
  final double percent;
  final Animation<double> percentAnim;
  final bool isSelected;
  final bool isWinner;
  final bool hasVoted;
  final VoidCallback onTap;

  const _PollOptionButton({
    required this.label,
    required this.percent,
    required this.percentAnim,
    required this.isSelected,
    required this.isWinner,
    required this.hasVoted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Voted progress bar fill
              if (hasVoted)
                AnimatedBuilder(
                  animation: percentAnim,
                  builder: (context, _) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percentAnim.value,
                      child: Container(
                        color: isWinner
                            ? const Color(0xFFC8E6C9) // Green tint
                            : const Color(0xFFE0E0E0), // Grey tint
                      ),
                    );
                  },
                ),

              // Labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: isWinner && hasVoted
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasVoted)
                      AnimatedBuilder(
                        animation: percentAnim,
                        builder: (context, _) {
                          final pct = (percentAnim.value * 100).round();
                          return Text(
                            '$pct%',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
