import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/story_model.dart';

class StoryController extends ChangeNotifier {
  // ─── User & story indices ─────────────────────────────
  final List<StoryUserModel> users;
  int currentUserIndex;
  int currentStoryIndex = 0;

  // ─── Animation controllers ────────────────────────────
  late AnimationController progressController;
  final TickerProvider vsync;

  // ─── Video ───────────────────────────────────────────
  VideoPlayerController? _videoController;
  bool isVideoReady = false;

  // ─── State flags ──────────────────────────────────────
  bool isPaused = false;
  bool isHolding = false;
  bool isInputFocused = false;
  bool isDisposed = false;
  bool showingReactions = false;
  bool isTransitioning = false;

  // ─── Swipe dismiss state ──────────────────────────────
  double dismissDragY = 0.0;
  double dismissScale = 1.0;
  double dismissOpacity = 1.0;

  StoryController({
    required this.users,
    required this.currentUserIndex,
    required this.vsync,
    required AnimationController progressController,
  }) {
    this.progressController = progressController;
    _initStory();
  }

  // ─── Getters ──────────────────────────────────────────
  StoryUserModel get currentUser => users[currentUserIndex];
  StoryModel get currentStory =>
      currentUser.stories[currentStoryIndex];
  bool get hasNextStory =>
      currentStoryIndex < currentUser.stories.length - 1;
  bool get hasPrevStory => currentStoryIndex > 0;
  bool get hasNextUser => currentUserIndex < users.length - 1;
  bool get hasPrevUser => currentUserIndex > 0;
  int get storyCount => currentUser.stories.length;
  VideoPlayerController? get videoController => _videoController;

  // ─── Init ─────────────────────────────────────────────
  void _initStory() {
    progressController.reset();

    final story = currentStory;

    if (story.mediaType == StoryMediaType.video) {
      _initVideo(story.mediaUrl);
    } else {
      _startProgress(story.duration);
    }
  }

  Future<void> _initVideo(String url) async {
    isVideoReady = false;
    notifyListeners();

    await _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));

    await _videoController!.initialize();

    if (isDisposed) return;

    isVideoReady = true;
    _videoController!.setLooping(false);
    _videoController!.play();

    // Use actual video duration
    final duration = _videoController!.value.duration;
    _startProgress(duration);

    _videoController!.addListener(_videoListener);
    notifyListeners();
  }

  void _videoListener() {
    if (_videoController?.value.isCompleted == true) {
      goToNext();
    }
  }

  void _startProgress(Duration duration) {
    progressController.duration = duration;
    progressController.forward();

    progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !isDisposed) {
        goToNext();
      }
    });
  }

  // ─── Navigation ───────────────────────────────────────
  void goToNext() {
    if (isTransitioning) return;
    HapticFeedback.selectionClick();

    if (hasNextStory) {
      currentStoryIndex++;
      _resetAndInit();
    } else if (hasNextUser) {
      isTransitioning = true;
      notifyListeners();
      // Handled by shell with cube transition
    } else {
      // End of all stories — close
      _closeViewer();
    }
  }

  void goToPrev() {
    if (isTransitioning) return;
    HapticFeedback.selectionClick();

    if (progressController.value > 0.08) {
      // Restart current story
      _resetAndInit();
    } else if (hasPrevStory) {
      currentStoryIndex--;
      _resetAndInit();
    } else if (hasPrevUser) {
      isTransitioning = true;
      notifyListeners();
    }
  }

  void _resetAndInit() {
    progressController.reset();
    progressController.removeStatusListener((_) {});
    _videoController?.dispose();
    _videoController = null;
    isVideoReady = false;
    isTransitioning = false;
    notifyListeners();
    _initStory();
  }

  void selectUser(int index) {
    if (index < 0 || index >= users.length) return;
    currentUserIndex = index;
    currentStoryIndex = 0;
    _resetAndInit();
  }

  VoidCallback? _closeCallback;
  void setCloseCallback(VoidCallback cb) => _closeCallback = cb;

  void _closeViewer() {
    _closeCallback?.call();
  }

  // ─── Pause / Resume ───────────────────────────────────
  void pause({bool holding = false}) {
    if (isPaused) return;
    isPaused = true;
    isHolding = holding;
    progressController.stop();
    _videoController?.pause();
    notifyListeners();
  }

  void resume() {
    if (!isPaused) return;
    isPaused = false;
    isHolding = false;
    progressController.forward();
    _videoController?.play();
    notifyListeners();
  }

  void onInputFocus(bool focused) {
    isInputFocused = focused;
    focused ? pause() : resume();
    notifyListeners();
  }

  // ─── Swipe dismiss ────────────────────────────────────
  void onDismissDragUpdate(double dy) {
    if (dy < 0) return; // Only down
    dismissDragY = dy;
    dismissScale = (1.0 - (dy / 600)).clamp(0.7, 1.0);
    dismissOpacity = (1.0 - (dy / 350)).clamp(0.0, 1.0);
    pause();
    notifyListeners();
  }

  void onDismissDragEnd(double velocity) {
    if (velocity > 800 || dismissDragY > 180) {
      _closeViewer();
    } else {
      // Snap back
      dismissDragY = 0;
      dismissScale = 1.0;
      dismissOpacity = 1.0;
      resume();
      notifyListeners();
    }
  }

  // ─── Reactions ────────────────────────────────────────
  void toggleReactions(bool show) {
    showingReactions = show;
    show ? pause() : resume();
    notifyListeners();
  }

  // ─── Poll vote ────────────────────────────────────────
  void votePoll(int option) {
    // API call + optimistic update
    notifyListeners();
  }

  // ─── Dispose ──────────────────────────────────────────
  @override
  void dispose() {
    isDisposed = true;
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }
}
