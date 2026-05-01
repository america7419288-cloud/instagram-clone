// lib/features/story/presentation/widgets/story_viewer.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/models/story_model.dart';
import '../providers/story_provider.dart';

class StoryViewer extends ConsumerStatefulWidget {
  final List<StoryUserGroup> groups;
  final int initialGroupIndex;

  const StoryViewer({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
  });

  @override
  ConsumerState<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends ConsumerState<StoryViewer>
    with TickerProviderStateMixin {
  // Current group (user) index
  late int _currentGroupIndex;

  // Current story index within group
  int _currentStoryIndex = 0;

  // Progress bar animation controller
  late AnimationController _progressController;

  // Story display duration
  static const Duration _storyDuration = Duration(seconds: 5);

  // Reply text controller
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocus = FocusNode();

  // Pause when holding
  bool _isPaused = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex;

    // Start at first unseen story
    final group = _currentGroup;
    _currentStoryIndex = group.firstUnseenIndex;

    _initProgressController();
    _startProgress();

    // Hide status bar for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    _replyFocus.dispose();
    // Restore status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─── GETTERS ──────────────────────────────────────────────
  StoryUserGroup get _currentGroup =>
      widget.groups[_currentGroupIndex];

  StoryModel get _currentStory =>
      _currentGroup.stories[_currentStoryIndex];

  bool get _isLastStoryInGroup =>
      _currentStoryIndex >= _currentGroup.stories.length - 1;

  bool get _isLastGroup =>
      _currentGroupIndex >= widget.groups.length - 1;

  // ─── PROGRESS CONTROLLER ──────────────────────────────────
  void _initProgressController() {
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToNextStory();
      }
    });
  }

  // ─── START PROGRESS ───────────────────────────────────────
  void _startProgress() {
    _progressController.reset();
    _progressController.forward();

    // Mark story as viewed
    _markCurrentStoryViewed();
  }

  // ─── MARK VIEWED ──────────────────────────────────────────
  void _markCurrentStoryViewed() {
    final story = _currentStory;
    final userId = _currentGroup.user.id;

    ref.read(storyFeedProvider.notifier).markStoryViewed(
          userId,
          story.id,
        );
  }

  // ─── NEXT STORY ───────────────────────────────────────────
  void _goToNextStory() {
    if (_isLastStoryInGroup) {
      // Move to next user's stories
      _goToNextGroup();
    } else {
      setState(() {
        _currentStoryIndex++;
      });
      _startProgress();
    }
  }

  // ─── PREVIOUS STORY ───────────────────────────────────────
  void _goToPreviousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _startProgress();
    } else {
      // Move to previous user's stories
      _goToPreviousGroup();
    }
  }

  // ─── NEXT GROUP ───────────────────────────────────────────
  void _goToNextGroup() {
    if (_isLastGroup) {
      // All stories done → close viewer
      Navigator.of(context).pop();
    } else {
      setState(() {
        _currentGroupIndex++;
        _currentStoryIndex = _currentGroup.firstUnseenIndex;
      });
      _startProgress();
    }
  }

  // ─── PREVIOUS GROUP ───────────────────────────────────────
  void _goToPreviousGroup() {
    if (_currentGroupIndex > 0) {
      setState(() {
        _currentGroupIndex--;
        _currentStoryIndex = 0;
      });
      _startProgress();
    }
  }

  // ─── PAUSE / RESUME ───────────────────────────────────────
  void _pauseStory() {
    if (!_isPaused) {
      _progressController.stop();
      setState(() => _isPaused = true);
    }
  }

  void _resumeStory() {
    if (_isPaused && !_isTyping) {
      _progressController.forward();
      setState(() => _isPaused = false);
    }
  }

  // ─── HANDLE TAP ───────────────────────────────────────────
  void _handleTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    if (tapX < screenWidth / 3) {
      // Tap left third → previous
      _goToPreviousStory();
    } else if (tapX > screenWidth * 2 / 3) {
      // Tap right third → next
      _goToNextStory();
    }
    // Tap middle → do nothing (or show info)
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final story = _currentStory;
    final group = _currentGroup;
    final isOwnStory = currentUser?.id == group.user.id;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Tap to navigate
        onTapDown: _isTyping ? null : _handleTapDown,

        // Hold to pause
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),

        // Swipe down to close
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },

        child: Stack(
          children: [
            // ─── STORY MEDIA ────────────────────────────────
            _buildStoryMedia(story),

            // ─── GRADIENT OVERLAYS ───────────────────────────
            // Top gradient (for progress bars + user info)
            Container(
              height: 150,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Bottom gradient (for reply input)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 150,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ─── TOP: PROGRESS BARS + USER INFO ─────────────
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress bars
                  _buildProgressBars(),
                  const SizedBox(height: 8),

                  // User info row
                  _buildUserInfo(group, story, isOwnStory),
                ],
              ),
            ),

            // ─── BOTTOM: CAPTION + REPLY INPUT ──────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Caption
                    if (story.caption != null &&
                        story.caption!.isNotEmpty)
                      _buildCaption(story.caption!),

                    const SizedBox(height: 8),

                    // Reply input or view count
                    isOwnStory
                        ? _buildViewCount(story)
                        : _buildReplyInput(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STORY MEDIA ──────────────────────────────────────────
  Widget _buildStoryMedia(StoryModel story) {
    return SizedBox.expand(
      child: story.isVideo
          ? Center(
              child: Text(
                '🎬 Video stories coming soon',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: story.mediaUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: Colors.grey[900],
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
            ),
    );
  }

  // ─── PROGRESS BARS ────────────────────────────────────────
  Widget _buildProgressBars() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(
          _currentGroup.stories.length,
          (index) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _StoryProgressBar(
                  // Past stories → full
                  // Current story → animated
                  // Future stories → empty
                  progress: index < _currentStoryIndex
                      ? 1.0
                      : index == _currentStoryIndex
                          ? _progressController
                          : 0.0,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── USER INFO ────────────────────────────────────────────
  Widget _buildUserInfo(
    StoryUserGroup group,
    StoryModel story,
    bool isOwnStory,
  ) {
    final timeText = story.createdAt != null
        ? timeago.format(story.createdAt!)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: ClipOval(
              child: group.user.profilePicUrl != null
                  ? CachedNetworkImage(
                      imageUrl: group.user.profilePicUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.border,
                      child: Center(
                        child: Text(
                          group.user.username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 10),

          // Username + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      group.user.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (group.user.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ],
                ),
                Text(
                  timeText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 26,
            ),
          ),

          // More options
          if (isOwnStory)
            IconButton(
              onPressed: () => _showStoryOptions(),
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }

  // ─── CAPTION ─────────────────────────────────────────────
  Widget _buildCaption(String caption) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          caption,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ─── VIEW COUNT (own stories) ─────────────────────────────
  Widget _buildViewCount(StoryModel story) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.remove_red_eye_outlined,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            '${story.viewCount} ${story.viewCount == 1 ? 'view' : 'views'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── REPLY INPUT ──────────────────────────────────────────
  Widget _buildReplyInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white60),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _replyController,
                focusNode: _replyFocus,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Reply to ${_currentGroup.user.username}...',
                  hintStyle: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onTap: () {
                  setState(() => _isTyping = true);
                  _pauseStory();
                },
                onSubmitted: (_) {
                  setState(() => _isTyping = false);
                  _replyController.clear();
                  _replyFocus.unfocus();
                  _resumeStory();
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Send heart reaction
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❤️ Reaction sent!'),
                  duration: Duration(seconds: 1),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
              );
            },
            child: const Text('❤️', style: TextStyle(fontSize: 28)),
          ),
        ],
      ),
    );
  }

  // ─── STORY OPTIONS (own stories) ─────────────────────────
  void _showStoryOptions() {
    _pauseStory();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          ListTile(
            leading: const Icon(
              Icons.delete_outline,
              color: Colors.red,
            ),
            title: const Text(
              'Delete Story',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              await _deleteCurrentStory();
            },
          ),

          ListTile(
            leading:
                const Icon(Icons.close, color: Colors.white),
            title: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _resumeStory();
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    ).whenComplete(() => _resumeStory());
  }

  // ─── DELETE STORY ─────────────────────────────────────────
  Future<void> _deleteCurrentStory() async {
    try {
      final storyId = _currentStory.id;
      await ref.read(storyServiceProvider).deleteStory(storyId);
      ref.read(storyFeedProvider.notifier).removeStory(storyId);

      if (_isLastStoryInGroup && _isLastGroup) {
        if (mounted) Navigator.of(context).pop();
      } else {
        _goToNextStory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}

// ─── STORY PROGRESS BAR ─────────────────────────────────────
class _StoryProgressBar extends StatelessWidget {
  // Can be double (0.0 or 1.0) or AnimationController
  final dynamic progress;

  const _StoryProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress is AnimationController) {
      // Animated progress bar
      return AnimatedBuilder(
        animation: progress as AnimationController,
        builder: (_, __) {
          return _buildBar(
            (progress as AnimationController).value,
          );
        },
      );
    }

    // Static bar (full or empty)
    return _buildBar(progress as double);
  }

  Widget _buildBar(double value) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: Colors.white30,
        valueColor: const AlwaysStoppedAnimation<Color>(
          Colors.white,
        ),
        minHeight: 3,
      ),
    );
  }
}