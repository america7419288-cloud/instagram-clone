// lib/features/story/presentation/widgets/story_viewer.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/models/story_model.dart';
import '../../data/repositories/story_service.dart';
import '../providers/story_provider.dart';

class StoryViewer extends ConsumerStatefulWidget {
  final List<StoryFeedModel> groups;
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
  late int _currentGroupIndex;
  int _currentStoryIndex = 0;
  late AnimationController _progressController;

  static const Duration _storyDuration = Duration(seconds: 5);

  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocus = FocusNode();

  bool _isPaused = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex;
    _currentStoryIndex = _currentGroup.firstUnseenIndex;

    _initProgressController();
    _startProgress();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    _replyFocus.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  StoryFeedModel get _currentGroup => widget.groups[_currentGroupIndex];

  StoryModel get _currentStory => _currentGroup.stories[_currentStoryIndex];

  bool get _isLastStoryInGroup =>
      _currentStoryIndex >= _currentGroup.stories.length - 1;

  bool get _isLastGroup => _currentGroupIndex >= widget.groups.length - 1;

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

  void _startProgress() {
    _progressController
      ..reset()
      ..forward();
    _markCurrentStoryViewed();
  }

  void _markCurrentStoryViewed() {
    // 💡 Fix: Defer state update to avoid "modify during build" error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(storyFeedProvider.notifier).markStoryViewed(
            _currentGroup.user.id,
            _currentStory.id,
          );
    });
  }

  void _goToNextStory() {
    if (_isLastStoryInGroup) {
      _goToNextGroup();
      return;
    }

    setState(() {
      _currentStoryIndex++;
    });
    _startProgress();
  }

  void _goToPreviousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _startProgress();
      return;
    }

    _goToPreviousGroup();
  }

  void _goToNextGroup() {
    if (_isLastGroup) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _currentGroupIndex++;
      _currentStoryIndex = _currentGroup.firstUnseenIndex;
    });
    _startProgress();
  }

  void _goToPreviousGroup() {
    if (_currentGroupIndex <= 0) return;

    setState(() {
      _currentGroupIndex--;
      _currentStoryIndex = 0;
    });
    _startProgress();
  }

  void _pauseStory() {
    if (_isPaused) return;
    _progressController.stop();
    setState(() => _isPaused = true);
  }

  void _resumeStory() {
    if (!_isPaused || _isTyping) return;
    _progressController.forward();
    setState(() => _isPaused = false);
  }

  void _handleTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    if (tapX < screenWidth / 3) {
      _goToPreviousStory();
    } else if (tapX > screenWidth * 2 / 3) {
      _goToNextStory();
    }
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
        onTapDown: _isTyping ? null : _handleTapDown,
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            _buildStoryMedia(story),
            _buildStickers(story),
            Container(
              height: 150,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
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
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressBars(),
                  const SizedBox(height: 8),
                  _buildUserInfo(group, story, isOwnStory),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (story.caption != null && story.caption!.isNotEmpty)
                      _buildCaption(story.caption!),
                    const SizedBox(height: 8),
                    isOwnStory ? _buildViewCount(story) : _buildReplyInput(),
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

  Widget _buildStoryMedia(StoryModel story) {
    return SizedBox.expand(
      child: story.isVideo
          ? const Center(
              child: Text(
                'Video stories coming soon',
                style: TextStyle(color: Colors.white, fontSize: 18),
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

  Widget _buildStickers(StoryModel story) {
    return Positioned.fill(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (story.poll != null) _buildPoll(story.poll!),
            if (story.question != null) _buildQuestion(story.question!),
          ],
        ),
      ),
    );
  }

  Widget _buildPoll(StoryPollModel poll) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            poll.question,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPollOption(
                  poll.optionA,
                  poll.percentA,
                  poll.myVote == 'a',
                  () => _votePoll('a'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPollOption(
                  poll.optionB,
                  poll.percentB,
                  poll.myVote == 'b',
                  () => _votePoll('b'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPollOption(
    String label,
    int percent,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // Progress bar background (simplified)
            if (percent > 0)
              FractionallySizedBox(
                widthFactor: percent / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            Center(
              child: Text(
                percent > 0 ? '$percent%' : label,
                style: TextStyle(
                  color: isSelected ? Colors.blue[700] : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(StoryQuestionModel question) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF194B4), // Classic pink sticker color
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              question.question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Type something...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              textAlign: TextAlign.center,
              onTap: () {
                _pauseStory();
                setState(() => _isTyping = true);
              },
              onSubmitted: (val) {
                _resumeStory();
                setState(() => _isTyping = false);
                if (val.isNotEmpty) {
                  _answerQuestion(val);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _votePoll(String option) async {
    try {
      await ref.read(storyServiceProvider).votePoll(
            storyId: _currentStory.id,
            option: option,
          );
      // Refresh feed to show results
      ref.invalidate(storyFeedProvider);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    }
  }

  void _answerQuestion(String answer) async {
    try {
      await ref.read(storyServiceProvider).answerQuestion(
            storyId: _currentStory.id,
            answer: answer,
          );
      if (mounted) AppSnackbar.success(context, 'Answer sent!');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    }
  }

  Widget _buildProgressBars() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(_currentGroup.stories.length, (index) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _StoryProgressBar(
                progress: index < _currentStoryIndex
                    ? 1.0
                    : index == _currentStoryIndex
                    ? _progressController
                    : 0.0,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildUserInfo(
    StoryFeedModel group,
    StoryModel story,
    bool isOwnStory,
  ) {
    final timeText =
        story.createdAt != null ? timeago.format(story.createdAt!) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
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
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 26),
          ),
          if (isOwnStory)
            IconButton(
              onPressed: _showStoryOptions,
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
            ),
        ],
      ),
    );
  }

  Widget _buildCaption(String caption) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Reply to ${_currentGroup.user.username}...',
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
          GestureDetector(
            onTap: () => AppSnackbar.success(context, 'Reaction sent!'),
            child: const Text('❤', style: TextStyle(fontSize: 28)),
          ),
        ],
      ),
    );
  }

  void _showStoryOptions() {
    _pauseStory();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
            leading: const Icon(Icons.delete_outline, color: Colors.red),
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
            leading: const Icon(Icons.close, color: Colors.white),
            title: const Text('Cancel', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              _resumeStory();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    ).whenComplete(_resumeStory);
  }

  Future<void> _deleteCurrentStory() async {
    try {
      final storyId = _currentStory.id;
      await ref.read(storyServiceProvider).deleteStory(storyId);
      ref.read(storyFeedProvider.notifier).removeStory(storyId);

      if (_isLastStoryInGroup && _isLastGroup) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _goToNextStory();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to delete: $e');
      }
    }
  }
}

class _StoryProgressBar extends StatelessWidget {
  final dynamic progress;

  const _StoryProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress is AnimationController) {
      return AnimatedBuilder(
        animation: progress as AnimationController,
        builder: (_, __) {
          return _buildBar((progress as AnimationController).value);
        },
      );
    }

    return _buildBar(progress as double);
  }

  Widget _buildBar(double value) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: Colors.white30,
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        minHeight: 3,
      ),
    );
  }
}
