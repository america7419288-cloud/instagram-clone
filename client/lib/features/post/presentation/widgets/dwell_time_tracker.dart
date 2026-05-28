// client/lib/features/post/presentation/widgets/dwell_time_tracker.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../data/repositories/post_service.dart';

// We get the postServiceProvider from where? Let's check post_service.dart.
// Since postServiceProvider is defined globally, we can use it.
final postServiceProvider = Provider<PostService>((ref) => PostService());

class DwellTimeTracker extends ConsumerStatefulWidget {
  final Widget child;
  final String contentId;
  final String contentType; // 'post' | 'reel' | 'story'
  final String? authorId;
  final String source; // 'feed' | 'explore' | 'reels'
  final List<String> categories;
  final List<String> hashtags;

  const DwellTimeTracker({
    super.key,
    required this.child,
    required this.contentId,
    required this.contentType,
    this.authorId,
    this.source = 'feed',
    this.categories = const [],
    this.hashtags = const [],
  });

  @override
  ConsumerState<DwellTimeTracker> createState() => _DwellTimeTrackerState();
}

class _DwellTimeTrackerState extends ConsumerState<DwellTimeTracker> {
  DateTime? _visibleStartTime;
  int _accumulatedDwellMs = 0;
  bool _isCurrentlyVisible = false;

  @override
  void dispose() {
    _logFinalDwellTime();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visiblePercentage = info.visibleFraction * 100;

    // Trigger dwell logging if visibility crosses 50%
    if (visiblePercentage >= 50) {
      if (!_isCurrentlyVisible) {
        _isCurrentlyVisible = true;
        _visibleStartTime = DateTime.now();
      }
    } else {
      if (_isCurrentlyVisible) {
        _isCurrentlyVisible = false;
        _logCurrentInterval();
      }
    }
  }

  void _logCurrentInterval() {
    if (_visibleStartTime == null) return;

    final duration = DateTime.now().difference(_visibleStartTime!).inMilliseconds;
    _accumulatedDwellMs += duration;
    _visibleStartTime = null;
  }

  void _logFinalDwellTime() {
    if (_isCurrentlyVisible) {
      _logCurrentInterval();
    }

    if (_accumulatedDwellMs > 0) {
      final dwellTimeMs = _accumulatedDwellMs;
      final contentId = widget.contentId;
      final contentType = widget.contentType;
      final authorId = widget.authorId;
      final source = widget.source;
      final categories = widget.categories;
      final hashtags = widget.hashtags;

      // Determine action type based on time spent
      String action = 'scroll_past';
      if (dwellTimeMs > 8000) {
        action = 'video_watch_50'; // standard deep interest
      } else if (dwellTimeMs > 3000) {
        action = 'carousel_swipe'; // shallow interest
      }

      // Record interaction asynchronously in a non-blocking way
      Future.microtask(() async {
        try {
          await ref.read(postServiceProvider).recordInteraction(
            contentId: contentId,
            contentType: contentType,
            action: action,
            authorId: authorId,
            dwellTime: dwellTimeMs,
            source: source,
            contentCategories: categories,
            contentHashtags: hashtags,
          );
        } catch (e) {
          debugPrint('Dwell interaction logging failed: $e');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('dwell_${widget.contentType}_${widget.contentId}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }
}
