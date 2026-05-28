import 'package:flutter/material.dart';

class StoryProgressBar extends StatelessWidget {
  final int count;
  final int currentIndex;
  final Animation<double> progressAnimation;

  const StoryProgressBar({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.progressAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index < count - 1 ? 3.0 : 0,
            ),
            child: _StoryProgressSegment(
              state: index < currentIndex
                  ? _SegmentState.complete
                  : index == currentIndex
                      ? _SegmentState.active
                      : _SegmentState.pending,
              progressAnimation: progressAnimation,
            ),
          ),
        );
      }),
    );
  }
}

enum _SegmentState { complete, active, pending }

class _StoryProgressSegment extends StatelessWidget {
  final _SegmentState state;
  final Animation<double> progressAnimation;

  const _StoryProgressSegment({
    required this.state,
    required this.progressAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2.2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: Colors.white.withOpacity(0.4),
      ),
      clipBehavior: Clip.hardEdge,
      child: AnimatedBuilder(
        animation: progressAnimation,
        builder: (context, _) {
          double value;
          switch (state) {
            case _SegmentState.complete:
              value = 1.0;
              break;
            case _SegmentState.active:
              value = progressAnimation.value;
              break;
            case _SegmentState.pending:
              value = 0.0;
              break;
          }

          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        },
      ),
    );
  }
}
