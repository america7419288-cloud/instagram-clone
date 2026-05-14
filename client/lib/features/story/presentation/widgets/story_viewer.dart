// lib/features/story/presentation/widgets/story_viewer.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:just_audio/just_audio.dart';

import 'package:instagram_clinet/core/network/audio_stream_source.dart';
import 'package:instagram_clinet/core/network/dio_client.dart';
import 'package:instagram_clinet/core/theme/app_theme.dart';
import 'package:instagram_clinet/shared/widgets/app_snackbar.dart';
import 'package:instagram_clinet/features/auth/presentation/providers/auth_provider.dart';
import '../../data/models/story_model.dart';
import '../../data/repositories/story_service.dart';
import 'package:instagram_clinet/features/share/models/share_content.dart';
import 'package:instagram_clinet/features/share/presentation/share_sheet.dart';
import '../providers/story_provider.dart';
import 'story_video_player.dart';
import 'package:instagram_clinet/features/menu/presentation/three_dot_menu.dart';
import 'package:instagram_clinet/features/menu/models/menu_context.dart';
import 'package:instagram_clinet/features/menu/models/menu_action.dart';

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
  late PageController _groupPageController;
  late int _currentGroupIndex;
  int _currentStoryIndex = 0;
  late AnimationController _progressController;

  Duration _currentStoryDuration = const Duration(seconds: 5);

  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocus = FocusNode();

  bool _isPaused = false;
  bool _isTyping = false;
  final TransformationController _transformationController =
      TransformationController();

  // For 3D transition
  double _pageOffset = 0.0;

  // Audio
  AudioPlayer? _audioPlayer;
  bool _isAudioInitializing = false;

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex;
    _currentStoryIndex = _currentGroup.firstUnseenIndex;
    _pageOffset = widget.initialGroupIndex.toDouble();

    _groupPageController = PageController(initialPage: widget.initialGroupIndex);
    _groupPageController.addListener(() {
      setState(() {
        _pageOffset = _groupPageController.page ?? 0.0;
      });
    });

    _initProgressController();
    
    // If first story is image, start progress immediately. 
    // If video, we wait for _onVideoDurationLoaded
    if (!_currentStory.isVideo) {
      _startProgress();
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _groupPageController.dispose();
    _progressController.dispose();
    _replyController.dispose();
    _replyFocus.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transformationController.dispose();
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
      duration: _currentStoryDuration,
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
    _playStoryAudio();
  }

  Future<void> _playStoryAudio() async {
    final music = _currentStory.music;
    if (music == null) {
      await _audioPlayer?.stop();
      return;
    }

    if (_isAudioInitializing) return;
    _isAudioInitializing = true;

    try {
      _audioPlayer ??= AudioPlayer();
      final dio = ref.read(dioClientProvider).dio;
      final source = BackendStreamAudioSource(dio, music.id);
      
      await _audioPlayer!.setAudioSource(source);
      await _audioPlayer!.seek(Duration(seconds: music.startTime));
      
      if (!_isPaused) {
        await _audioPlayer!.play();
      }
    } catch (e) {
      debugPrint('Story Audio Error: $e');
    } finally {
      _isAudioInitializing = false;
    }
  }

  void _markCurrentStoryViewed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(storyFeedProvider.notifier).markStoryViewed(
            _currentGroup.user.id,
            _currentStory.id,
          );
    });
  }

  void _onVideoDurationLoaded(Duration duration) {
    setState(() {
      _currentStoryDuration = duration;
      _progressController.duration = duration;
    });
    _startProgress();
  }

  void _goToNextStory() {
    if (_isLastStoryInGroup) {
      _goToNextGroup();
      return;
    }

    if (_isTyping) {
      _replyFocus.unfocus();
      setState(() => _isTyping = false);
    }

    setState(() {
      _currentStoryIndex++;
      _currentStoryDuration = _currentStory.isVideo 
          ? const Duration(seconds: 15) // placeholder until loaded
          : const Duration(seconds: 5);
      _progressController.duration = _currentStoryDuration;
    });
    
    if (!_currentStory.isVideo) {
      _startProgress();
    }
  }

  void _goToPreviousStory() {
    if (_isTyping) {
      _replyFocus.unfocus();
      setState(() => _isTyping = false);
    }

    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
        _currentStoryDuration = _currentStory.isVideo 
            ? const Duration(seconds: 15)
            : const Duration(seconds: 5);
        _progressController.duration = _currentStoryDuration;
      });
      
      if (!_currentStory.isVideo) {
        _startProgress();
      }
      return;
    }

    _goToPreviousGroup();
  }

  void _goToNextGroup() {
    if (_isLastGroup) {
      Navigator.of(context).pop();
      return;
    }

    _groupPageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _goToPreviousGroup() {
    if (_currentGroupIndex <= 0) {
      // Just restart current story if first group
      _startProgress();
      return;
    }

    _groupPageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _pauseStory() {
    if (_isPaused) return;
    _progressController.stop();
    _audioPlayer?.pause();
    setState(() => _isPaused = true);
  }

  void _resumeStory() {
    if (!_isPaused || _isTyping) return;
    _progressController.forward();
    _audioPlayer?.play();
    setState(() => _isPaused = false);
  }

  void _handleTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    if (tapX < screenWidth * 0.3) {
      _goToPreviousStory();
    } else {
      _goToNextStory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _groupPageController,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.groups.length,
        onPageChanged: (index) {
          setState(() {
            _currentGroupIndex = index;
            _currentStoryIndex = 0;
            _currentStoryDuration = _currentStory.isVideo 
                ? const Duration(seconds: 15)
                : const Duration(seconds: 5);
            _progressController.duration = _currentStoryDuration;
          });
          
          if (!_currentStory.isVideo) {
            _startProgress();
          }
        },
        itemBuilder: (context, index) {
          // 3D Cube Transition Logic
          double value = 0.0;
          if (_pageOffset >= index - 1 && _pageOffset <= index + 1) {
            value = index - _pageOffset;
          }
          
          // Rotation angle
          final angle = value * -0.5; // adjust for tilt intensity
          
          return Transform(
            alignment: value >= 0 ? Alignment.centerLeft : Alignment.centerRight,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: _buildGroupItem(index),
          );
        },
      ),
    );
  }

  double _dragOffset = 0.0;
  bool _isDragging = false;

  Widget _buildGroupItem(int groupIndex) {
    if (groupIndex != _currentGroupIndex) {
      final group = widget.groups[groupIndex];
      return _buildStoryMedia(group.stories[0]);
    }

    final currentUser = ref.watch(currentUserProvider);
    final story = _currentStory;
    final group = _currentGroup;
    final isOwnStory = currentUser?.id == group.user.id;

    // Calculate scale and opacity based on drag
    final dragScale = (1.0 - (_dragOffset / 500)).clamp(0.8, 1.0);
    final dragOpacity = (1.0 - (_dragOffset / 300)).clamp(0.0, 1.0);

    return GestureDetector(
      onTapDown: _isTyping ? null : _handleTapDown,
      onLongPressStart: (_) => _pauseStory(),
      onLongPressEnd: (_) => _resumeStory(),
      onVerticalDragStart: (_) {
        setState(() => _isDragging = true);
        _pauseStory();
      },
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 0 || _dragOffset > 0) {
          setState(() {
            _dragOffset += details.delta.dy;
          });
        }
      },
      onVerticalDragEnd: (details) {
        if (_dragOffset > 100) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _dragOffset = 0;
            _isDragging = false;
          });
          _resumeStory();
        }
      },
      child: Container(
        color: Colors.black.withValues(alpha: dragOpacity),
        child: Transform.scale(
          scale: dragScale,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_dragOffset > 0 ? 12 : 0),
            child: Stack(
              children: [
                _buildStoryMedia(story),
                _buildGradients(),
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
                _buildBottomSection(story, group, isOwnStory),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradients() {
    return Stack(
      children: [
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
      ],
    );
  }

  Widget _buildBottomSection(StoryModel story, StoryFeedModel group, bool isOwnStory) {
    return Positioned(
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
    );
  }

  Widget _buildStoryMedia(StoryModel story) {
    return SizedBox.expand(
      child: story.isVideo
          ? StoryVideoPlayer(
              url: story.mediaUrl,
              isPaused: _isPaused || _isTyping || _isDragging,
              onVideoFinished: _goToNextStory,
              onDurationLoaded: _onVideoDurationLoaded,
            )
          : InteractiveViewer(
              transformationController: _transformationController,
              clipBehavior: Clip.none,
              minScale: 1.0,
              maxScale: 4.0,
              onInteractionEnd: (details) {
                _transformationController.value = Matrix4.identity();
              },
              child: CachedNetworkImage(
                imageUrl: story.mediaUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: CupertinoActivityIndicator(
                      color: Colors.white,
                      radius: 10,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[900],
                  child: Center(
                    child: Icon(
                      PhosphorIcons.imageBroken(),
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
    );
  }


  Widget _buildProgressBars() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: List.generate(_currentGroup.stories.length, (index) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1), // 2pt spacing total
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
    // Exact timestamp formatting "2h"
    final timeText = _formatTimeText(story.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 32x32 Avatar
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(shape: BoxShape.circle),
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
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                group.user.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFamily: 'SF-Pro',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontFamily: 'SF-Pro',
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _showStoryOptions,
                icon: Icon(PhosphorIcons.dotsThreeVertical(), color: Colors.white, size: 24),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(PhosphorIcons.x(), color: Colors.white, size: 20),
              ),
            ],
          ),
          if (story.music != null)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 4),
              child: Row(
                children: [
                  const Icon(PhosphorIconsFill.musicNotes, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${story.music!.title} • ${story.music!.artist}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'SF-Pro',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimeText(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Widget _buildCaption(String caption) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        caption,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'SF-Pro',
        ),
        textAlign: TextAlign.start,
      ),
    );
  }

  Widget _buildViewCount(StoryModel story) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Seen by ${story.viewCount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isTyping) _buildReactionEmojis(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _replyController,
                    focusNode: _replyFocus,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Send message',
                      hintStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
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
                onTap: () {
                  _pauseStory();
                  ShareSheet.show(
                    context,
                    content: ShareContent(
                      id: _currentStory.id,
                      type: ShareContentType.story,
                      thumbnailUrl: _currentStory.mediaUrl,
                      authorUsername: _currentGroup.user.username,
                      authorAvatarUrl: _currentGroup.user.profilePicUrl,
                      caption: _currentStory.caption,
                    ),
                  ).then((_) => _resumeStory());
                },
                child: Icon(PhosphorIcons.paperPlaneTilt(), color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Icon(PhosphorIcons.heart(), color: Colors.white, size: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReactionEmojis() {
    final emojis = ['😂', '😮', '😍', '😢', '👏', '🔥'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: emojis.map((emoji) {
          return GestureDetector(
            onTap: () {
              AppSnackbar.success(context, 'Sent $emoji');
              setState(() => _isTyping = false);
              _replyFocus.unfocus();
              _resumeStory();
            },
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          );
        }).toList(),
      ),
    );
  }

  void _showStoryOptions() {
    _pauseStory();

    final currentUser = ref.read(currentUserProvider);
    final group = _currentGroup;
    final story = _currentStory;
    final isOwnStory = currentUser?.id == group.user.id;

    final relationship = isOwnStory
        ? MenuRelationship.owner
        : (group.user.isFollowing
            ? MenuRelationship.following
            : MenuRelationship.notFollowing);

    final menuContext = MenuContext(
      contentId: story.id,
      contentType: MenuContentType.story,
      relationship: relationship,
      authorId: group.user.id,
      authorUsername: group.user.username,
      authorAvatarUrl: group.user.profilePicUrl,
      canDelete: isOwnStory,
      canEdit: isOwnStory,
      canDownload: true,
    );

    InstagramMenu.show(
      context,
      menuContext: menuContext,
      onAction: _handleMenuAction,
    ).then((_) => _resumeStory());
  }

  Future<void> _handleMenuAction(MenuAction action) async {
    switch (action.type) {
      case MenuActionType.copyLink:
        Clipboard.setData(ClipboardData(text: 'https://instagram.com/stories/${_currentGroup.user.username}/${_currentStory.id}'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard')),
        );
        break;
      case MenuActionType.delete:
        _deleteCurrentStory();
        break;
      case MenuActionType.save:
        // TODO: Implement save
        break;
      case MenuActionType.report:
        // Handled by menu sub-flow
        break;
      default:
        break;
    }
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
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(1),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}
