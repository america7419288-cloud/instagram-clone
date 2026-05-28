import 'package:flutter/material.dart';
import '../models/story_model.dart';
import '../controllers/story_controller.dart';
import '../widgets/story_swipe_indicator.dart';
import 'story_viewer_page.dart';

class StoryViewerShell extends StatefulWidget {
  final List<StoryUserModel> users;
  final int initialUserIndex;
  final String currentUserId;
  final Rect? sourceRect; // for close animation

  const StoryViewerShell({
    super.key,
    required this.users,
    required this.initialUserIndex,
    required this.currentUserId,
    this.sourceRect,
  });

  @override
  State<StoryViewerShell> createState() => _StoryViewerShellState();
}

class _StoryViewerShellState extends State<StoryViewerShell>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late StoryController _storyController;
  late AnimationController _progressController;
  int _currentUserIndex = 0;
  bool _isDragging = false;
  double _dragProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialUserIndex;

    _pageController = PageController(
      initialPage: widget.initialUserIndex,
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _storyController = StoryController(
      users: widget.users,
      currentUserIndex: widget.initialUserIndex,
      vsync: this,
      progressController: _progressController,
    );

    _storyController.setCloseCallback(() {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });

    _storyController.addListener(_onStoryControllerUpdated);
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _storyController.removeListener(_onStoryControllerUpdated);
    _storyController.dispose();
    _progressController.dispose();
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onStoryControllerUpdated() {
    if (_storyController.isTransitioning) {
      final nextIndex = _storyController.currentUserIndex + 1;
      if (nextIndex < widget.users.length) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      } else {
        // No more users - close
        Navigator.of(context).pop();
      }
    }
  }

  void _onPageScroll() {
    if (_pageController.position.haveDimensions) {
      final double page = _pageController.page ?? 0.0;
      final int currentPage = page.floor();
      final double fractional = page - currentPage;

      if (fractional > 0.01 && fractional < 0.99) {
        setState(() {
          _isDragging = true;
          _dragProgress = fractional;
        });
      } else {
        setState(() {
          _isDragging = false;
        });
      }
    }
  }

  void _handlePageChanged(int index) {
    setState(() {
      _currentUserIndex = index;
    });
    _storyController.selectUser(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 3D Cube Transitions PageView
          PageView.builder(
            controller: _pageController,
            onPageChanged: _handlePageChanged,
            itemCount: widget.users.length,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 0.0;
                  if (_pageController.position.haveDimensions) {
                    value = index - (_pageController.page ?? 0.0);
                  } else {
                    value = index - widget.initialUserIndex.toDouble();
                  }

                  // 3D Rotation Transform Matrix
                  final double rotateY = value * 0.45; // Cube angle rotation
                  final double opacity = (1.0 - value.abs().clamp(0.0, 1.0));

                  return Transform(
                    alignment: value < 0 ? Alignment.centerRight : Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // perspective projection
                      ..rotateY(rotateY),
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: StoryViewerPage(
                  controller: _storyController,
                  user: widget.users[index],
                  isActive: index == _currentUserIndex,
                ),
              );
            },
          ),

          // Edge Swipe peeking indicators
          if (_isDragging) ...[
            if (_currentUserIndex < widget.users.length - 1)
              StorySwipeIndicator(
                user: widget.users[_currentUserIndex + 1],
                direction: SwipeDirection.right,
                dragProgress: _dragProgress,
              ),
            if (_currentUserIndex > 0)
              StorySwipeIndicator(
                user: widget.users[_currentUserIndex - 1],
                direction: SwipeDirection.left,
                dragProgress: 1.0 - _dragProgress,
              ),
          ],
        ],
      ),
    );
  }
}
