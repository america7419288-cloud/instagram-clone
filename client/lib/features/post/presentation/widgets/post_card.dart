// lib/features/post/presentation/widgets/post_card.dart

import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:instagram_client/core/constants/app_assets.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:visibility_detector/visibility_detector.dart';
import 'package:just_audio/just_audio.dart';

import 'package:instagram_client/features/menu/presentation/three_dot_menu.dart';
import 'package:instagram_client/features/menu/models/menu_context.dart';
import 'package:instagram_client/features/menu/models/menu_action.dart';
import 'package:instagram_client/features/auth/presentation/providers/auth_provider.dart';
import 'package:instagram_client/features/follow/data/repositories/presentation/providers/follow_provider.dart';

import '../../data/models/post_model.dart';
import '../providers/feed_provider.dart';
import 'package:instagram_client/shared/widgets/spring_widget.dart';
import 'package:instagram_client/shared/widgets/user_story_avatar.dart';
import 'video_player_widget.dart';
import '../pages/comments_page.dart';
import 'package:instagram_client/core/network/audio_stream_source.dart';
import 'package:instagram_client/core/network/dio_client.dart';
import '../providers/audio_playback_provider.dart';
import '../../data/models/post_tag_model.dart';
import '../../data/repositories/post_tag_service.dart';
import 'tag_view_overlay.dart';
import 'package:instagram_client/shared/widgets/verified_badge.dart';
import 'package:instagram_client/core/widgets/instagram_heart_animation.dart';
import 'package:instagram_client/features/share/presentation/share_sheet.dart';
import 'package:instagram_client/features/share/models/share_content.dart';
import 'dwell_time_tracker.dart';
import 'package:instagram_client/features/settings/presentation/providers/not_interested_provider.dart';

class ZoomNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setZooming(bool value) {
    state = value;
  }
}

final isZoomingProvider = NotifierProvider<ZoomNotifier, bool>(
  ZoomNotifier.new,
);

class PostCard extends ConsumerStatefulWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with TickerProviderStateMixin {
  
  late AnimationController _likeBounceController;
  late Animation<double> _likeBounceScale;

  late AnimationController _saveBounceController;
  late Animation<double> _saveBounceScale;

  late AnimationController _zoomAnimationController;
  double _startScale = 1.0;
  double _startTranslationX = 0.0;
  double _startTranslationY = 0.0;

  // ─── State ────────────────────────────────────────────
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isSaved = false;
  bool _showHeartOverlay = false;
  bool _heartAnimating = false;
  int _heartTrigger = 0;
  Offset _tapPosition = Offset.zero;
  int _currentPage = 0;
  bool _captionExpanded = false;

  // ─── Tags ───────────────────────────────────────────
  List<PostTagModel> _tags = [];
  bool _showTags = false;
  bool _tagsLoaded = false;
  int _activePointers = 0;

  final PageController _pageController = PageController();
  final TransformationController _transformationController = TransformationController();

  // ─── Audio ────────────────────────────────────────────
  AudioPlayer? _audioPlayer;
  StreamSubscription? _audioSubscription;
  bool _isInitializingAudio = false;
  bool _isVisible = false;
  bool _isMuted = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likesCount;
    _isSaved = widget.post.isSaved;

    _likeBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _likeBounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.elasticOut)), 
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), 
        weight: 50,
      ),
    ]).animate(_likeBounceController);

    _saveBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _saveBounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.1), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 30),
    ]).animate(_saveBounceController);

    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    final CurvedAnimation zoomCurve = CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeOutQuint,
    );

    _zoomAnimationController.addListener(() {
      final double t = zoomCurve.value;
      final double animatedScale = _startScale + (1.0 - _startScale) * t;
      final double animatedX = _startTranslationX * (1.0 - t);
      final double animatedY = _startTranslationY * (1.0 - t);

      _transformationController.value = Matrix4.identity()
        ..translate(animatedX, animatedY)
        ..scale(animatedScale);
    });
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id == oldWidget.post.id) {
      bool changed = false;
      if (widget.post.isLiked != oldWidget.post.isLiked) {
        _isLiked = widget.post.isLiked;
        changed = true;
      }
      if (widget.post.likesCount != oldWidget.post.likesCount) {
        _likeCount = widget.post.likesCount;
        changed = true;
      }
      if (widget.post.isSaved != oldWidget.post.isSaved) {
        _isSaved = widget.post.isSaved;
        changed = true;
      }
      if (changed && mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadTags({bool force = false}) async {
    if (_tagsLoaded && !force) return;
    try {
      final tags = await ref
          .read(postTagServiceProvider)
          .getPostTags(widget.post.id);
      if (mounted) {
        setState(() {
          _tags      = tags;
          _tagsLoaded = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _initAudio() async {
    if (_isInitializingAudio || _audioPlayer != null) return;
    _isInitializingAudio = true;
    
    _audioPlayer = AudioPlayer();
    final dio = ref.read(dioClientProvider).dio;
    
    try {
      final source = await BackendStreamAudioSource.getPlayableSource(dio, widget.post.musicId!);
      await _audioPlayer!.setAudioSource(source);
      
      // Loop the 30s clip
      await _audioPlayer!.setLoopMode(LoopMode.one);
      
      // Set start time
      if (widget.post.musicStartTime != null) {
        await _audioPlayer!.seek(Duration(seconds: widget.post.musicStartTime!));
      }

      // Clip listener: reset if it goes beyond 30s from start
      _audioSubscription = _audioPlayer!.positionStream.listen((pos) {
        if (widget.post.musicStartTime != null) {
          final start = Duration(seconds: widget.post.musicStartTime!);
          final end = start + const Duration(seconds: 30);
          if (pos >= end) {
            _audioPlayer!.seek(start);
          }
        }
      });

      if (_isVisible) {
        _audioPlayer!.play();
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      print('❌ PostCard Audio Error: $e');
    } finally {
      _isInitializingAudio = false;
    }
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _audioPlayer?.dispose();
    _likeBounceController.dispose();
    _saveBounceController.dispose();
    _pageController.dispose();
    _transformationController.dispose();
    _zoomAnimationController.dispose();
    super.dispose();
  }

  // ─── Logic ───────────────────────────────────────────
  bool _showParticles = false;

  int _lastHeartTime = 0;

  void _handleLike({bool isDoubleTap = false}) {
    if (isDoubleTap) {
      // Single gate — if heart is already on screen, ignore
      if (_heartAnimating) return;

      if (!_isLiked) {
        _likeBounceController.forward(from: 0);
        setState(() {
          _isLiked = true;
          _likeCount += 1;
        });
        ref.read(feedProvider.notifier).toggleLike(widget.post.id);
      }

      setState(() {
        _heartAnimating = true;
        _showHeartOverlay = true;
        _showParticles = true;
        _heartTrigger++; // Increment trigger to ensure fresh state if needed
      });
    } else {
      // Regular like button tap
      _likeBounceController.forward(from: 0);
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      ref.read(feedProvider.notifier).toggleLike(widget.post.id);
    }
  }

  void _handleSave() {
    HapticFeedback.lightImpact();
    _saveBounceController.forward(from: 0);
    setState(() => _isSaved = !_isSaved);
    if (_isSaved) {
      ref.read(feedProvider.notifier).savePost(widget.post.id);
    } else {
      ref.read(feedProvider.notifier).unsavePost(widget.post.id);
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;

    final wasVisible = _isVisible;
    _isVisible = info.visibleFraction > 0.7; // Higher threshold for auto-play
    
    // Lazy load tags and audio when reasonably visible
    if (info.visibleFraction > 0.1) {
      if (!_tagsLoaded) _loadTags();
      if (widget.post.musicId != null && _audioPlayer == null && !_isInitializingAudio) {
        _initAudio();
      }
    }
    
    if (_isVisible && !wasVisible && widget.post.musicId != null) {
      // This post became prominently visible, take over audio
      ref.read(playingPostIdProvider.notifier).setPlaying(widget.post.id);
    } else if (!_isVisible && wasVisible && ref.read(playingPostIdProvider) == widget.post.id) {
      // This post was playing but is now scrolled away
      ref.read(playingPostIdProvider.notifier).setPlaying(null);
    }

    if (_audioPlayer != null) {
      if (_isVisible && ref.read(playingPostIdProvider) == widget.post.id) {
        _audioPlayer!.play();
        _isPlaying = true;
      } else {
        _audioPlayer!.pause();
        _isPlaying = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    // Listen for global audio changes to pause if another post starts playing
    ref.listen(playingPostIdProvider, (previous, next) {
      if (next != widget.post.id && _isPlaying) {
        _audioPlayer?.pause();
        setState(() => _isPlaying = false);
      } else if (next == widget.post.id && _isVisible && !_isPlaying) {
        _audioPlayer?.play();
        setState(() => _isPlaying = true);
      }
    });

    final hashtags = <String>[];
    if (widget.post.caption != null) {
      final regExp = RegExp(r'#\w+');
      hashtags.addAll(regExp.allMatches(widget.post.caption!).map((m) => m.group(0)!.substring(1)));
    }
    
    return DwellTimeTracker(
      contentId: widget.post.id,
      contentType: 'post',
      authorId: widget.post.userId,
      hashtags: hashtags,
      child: VisibilityDetector(
        key: Key('post-${widget.post.id}'),
        onVisibilityChanged: _onVisibilityChanged,
        child: Container(
          color: isDark ? Colors.black : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              _buildMedia(isDark),
              _buildActionRow(isDark),
              if (_tags.isNotEmpty)
                TaggedUsersRow(tags: _tags, isDark: isDark),
              _buildLikes(isDark),
              _buildCaption(isDark),
              _buildCommentsPreview(isDark),
              _buildTimestamp(isDark),
              const SizedBox(height: 12), // Reduced for a tighter feed
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header (56pt) ────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Avatar with live story ring
            UserStoryAvatar(
              userId: widget.post.userId,
              profilePicUrl: widget.post.userAvatar,
              username: widget.post.username,
              size: 32,
              showPresence: false,
              isClickable: true,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BouncyTap(
                        onTap: () => context.push('/profile/${widget.post.username}'),
                        child: Text(
                          widget.post.username,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Instagram-Sans',
                            color: isDark ? Colors.white : const Color(0xFF262626),
                          ),
                        ),
                      ),
                      if (widget.post.isVerified)
                        const VerifiedBadge(size: 12),
                    ],
                  ),
                  if (widget.post.location != null)
                    Text(
                      widget.post.location!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : const Color(0xFF262626),
                      ),
                    ),
                  if (widget.post.musicId != null) ...[
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Icon(LucideIcons.music, size: 10, color: isDark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${widget.post.musicTitle} • ${widget.post.musicArtist}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white70 : const Color(0xFF262626),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            BouncyTap(
              onTap: () => _showPostOptions(context),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  LucideIcons.ellipsis,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Media Section ───────────────────────────────────
  Widget _buildMedia(bool isDark) {
    final width = MediaQuery.of(context).size.width;

    return GestureDetector(
      onDoubleTapDown: (details) => _tapPosition = details.localPosition,
      onDoubleTap: () => _handleLike(isDoubleTap: true),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Media content
          AspectRatio(
            aspectRatio: widget.post.mediaFiles.isNotEmpty && 
                        widget.post.mediaFiles.first.width != null && 
                        widget.post.mediaFiles.first.height != null
                ? (widget.post.mediaFiles.first.width! / widget.post.mediaFiles.first.height!)
                : 1.0, // Default to square if no dimensions
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.post.mediaFiles.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final media = widget.post.mediaFiles[index];
                if (media.isVideo) {
                  return VideoPlayerWidget(
                    videoUrl: media.url,
                    fit: BoxFit.contain, // Show full video without cropping
                  );
                }
                return Listener(
                  onPointerDown: (event) {
                    _activePointers++;
                    if (_activePointers >= 2) {
                      ref.read(isZoomingProvider.notifier).setZooming(true);
                      final scrollable = Scrollable.maybeOf(context);
                      if (scrollable != null) {
                        try {
                          scrollable.position.jumpTo(scrollable.position.pixels);
                        } catch (_) {}
                      }
                    }
                  },
                  onPointerUp: (event) {
                    _activePointers = (_activePointers - 1).clamp(0, 10);
                  },
                  onPointerCancel: (event) {
                    _activePointers = (_activePointers - 1).clamp(0, 10);
                  },
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    clipBehavior: Clip.none,
                    minScale: 1.0,
                    maxScale: 4.0,
                    onInteractionStart: (details) {
                      if (_zoomAnimationController.isAnimating) {
                        _zoomAnimationController.stop();
                      }
                      if (details.pointerCount >= 2) {
                        ref.read(isZoomingProvider.notifier).setZooming(true);
                        final scrollable = Scrollable.maybeOf(context);
                        if (scrollable != null) {
                          try {
                            scrollable.position.jumpTo(scrollable.position.pixels);
                          } catch (_) {}
                        }
                      }
                    },
                    onInteractionUpdate: (details) {
                      if (details.scale != 1.0) {
                        ref.read(isZoomingProvider.notifier).setZooming(true);
                      }
                    },
                    onInteractionEnd: (details) {
                      _activePointers = 0;
                      final Matrix4 matrix = _transformationController.value;
                      final double currentScale = matrix.storage[0];
                      
                      if (currentScale > 1.0) {
                        _startScale = currentScale;
                        _startTranslationX = matrix.storage[12];
                        _startTranslationY = matrix.storage[13];
                        
                        _zoomAnimationController.forward(from: 0.0).then((_) {
                          ref.read(isZoomingProvider.notifier).setZooming(false);
                        });
                      } else {
                        ref.read(isZoomingProvider.notifier).setZooming(false);
                      }
                    },
                    child: CachedNetworkImage(
                      imageUrl: media.url,
                      fit: BoxFit.contain, // Show full image without cropping
                      width: width,
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Tap detector for tags
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (_tags.isNotEmpty) {
                  setState(() => _showTags = !_showTags);
                  if (_showTags) {
                    Future.delayed(const Duration(seconds: 3), () {
                      if (mounted) setState(() => _showTags = false);
                    });
                  }
                }
              },
              behavior: HitTestBehavior.translucent,
            ),
          ),

          // TagViewOverlay
          if (_showTags && _tags.isNotEmpty)
            Positioned.fill(
              child: TagViewOverlay(
                tags:       _tags,
                imgWidth:   width,
                imgHeight:  width, // assuming 1:1
                mediaIndex: _currentPage,
                onRefresh:  () => _loadTags(force: true),
              ),
            ),

          // Tag indicator (bottom left)
          if (_tags.isNotEmpty && !_showTags)
            Positioned(
              bottom: 12,
              left:   12,
              child:  GestureDetector(
                onTap: () => setState(() => _showTags = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical:   4,
                  ),
                  decoration: BoxDecoration(
                    color:        Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.user,
                    color: Colors.white,
                    size:  14,
                  ),
                ),
              ),
            ),
          
          // Particles
          if (_showParticles)
            Positioned.fill(
              child: IgnorePointer(
                child: LikeParticles(position: _tapPosition),
              ),
            ),

          // Instagram Heart Animation Wrapper (Positioned at tap location)
          if (_showHeartOverlay)
            Positioned(
              left: _tapPosition.dx - 50, // Half of heart size (100)
              top: _tapPosition.dy - 50,
              child: InstagramHeartAnimation(
                key: ValueKey('heart-$_heartTrigger'),
                isAnimating: _showHeartOverlay,
                duration: const Duration(milliseconds: 1000), // Match particles
                onEnd: () => setState(() {
                  _showHeartOverlay = false;
                  _showParticles = false; // Synchronized cleanup
                  _heartAnimating = false;
                }),
                child: const SizedBox.shrink(),
              ),
            ),

          // Pagination Dots
          if (widget.post.mediaFiles.length > 1)
            Positioned(
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.post.mediaFiles.length,
                  (index) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index ? const Color(0xFF0095F6) : const Color(0xFFA8A8A8),
                    ),
                  ),
                ),
              ),
            ),
          // Mute Button (Bottom Right)
          if (widget.post.musicId != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: () {
                  setState(() => _isMuted = !_isMuted);
                  _audioPlayer?.setVolume(_isMuted ? 0 : 1);
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMuted 
                        ? LucideIcons.volume_x
                        : LucideIcons.volume_2,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Action Row (40pt) ────────────────────────────────
  Widget _buildActionRow(bool isDark) {
    final iconColor = isDark ? Colors.white : Colors.black;

    return SizedBox(
      height: 46, // Standard IG action row height
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Like
            BouncyTap(
              onTap: () => _handleLike(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ScaleTransition(
                  scale: _likeBounceScale,
                  child: SvgPicture.asset(
                    AppAssets.getIcon('Name=Like', isDark: isDark, state: _isLiked ? 'Active' : 'Default'),
                    width: 27,
                    height: 27,
                    // If active, we use the original color (red) from the SVG, otherwise we tint it.
                    colorFilter: _isLiked ? null : ColorFilter.mode(iconColor, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
            // Comment
            BouncyTap(
              onTap: () => _showComments(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SvgPicture.asset(
                  AppAssets.getIcon('Name=Comment', isDark: isDark, state: 'Default'),
                  width: 27,
                  height: 27,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
            ),
            // Share
            BouncyTap(
              onTap: () {
                HapticFeedback.mediumImpact();
                ShareSheet.show(
                  context,
                  content: ShareContent(
                    id: widget.post.id,
                    type: ShareContentType.post,
                    thumbnailUrl: widget.post.mediaFiles.isNotEmpty ? widget.post.mediaFiles.first.url : null,
                    authorUsername: widget.post.username,
                    authorAvatarUrl: widget.post.userAvatar,
                    caption: widget.post.caption,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SvgPicture.asset(
                  AppAssets.getIcon('Name=Share', isDark: isDark, state: 'Default'),
                  width: 27,
                  height: 27,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
            ),
            const Spacer(),
            // Save
            BouncyTap(
              onTap: _handleSave,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ScaleTransition(
                  scale: _saveBounceScale,
                  child: Icon(
                    _isSaved ? Icons.bookmark : LucideIcons.bookmark,
                    color: iconColor,
                    size: 27,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Likes Count ─────────────────────────────────────
  Widget _buildLikes(bool isDark) {
    if (_likeCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Text(
        '$_likeCount likes',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'Instagram-Sans',
          color: isDark ? Colors.white : const Color(0xFF262626),
        ),
      ),
    );
  }

  // ─── Caption ─────────────────────────────────────────
  Widget _buildCaption(bool isDark) {
    final caption = widget.post.caption ?? '';
    if (caption.isEmpty) return const SizedBox.shrink();

    final showMore = !_captionExpanded && caption.length > 100;
    final displayCaption = showMore ? '${caption.substring(0, 100)}' : caption;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: GestureDetector(
          onTap: () {
            if (caption.length > 100) {
              setState(() => _captionExpanded = !_captionExpanded);
            }
          },
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF262626),
                fontFamily: 'Instagram-Sans',
              ),
              children: [
                TextSpan(
                  text: '${widget.post.username} ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => context.push('/profile/${widget.post.username}'),
                ),
                if (widget.post.isVerified)
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: VerifiedBadge(size: 11),
                  ),
                const TextSpan(text: ' '),
                TextSpan(text: displayCaption),
                if (showMore)
                  TextSpan(
                    text: '... more',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF8E8E8E),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Comments Preview ────────────────────────────────
  Widget _buildCommentsPreview(bool isDark) {
    if (widget.post.commentsCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: BouncyTap(
        onTap: () => _showComments(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'View all ${widget.post.commentsCount} comments',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : const Color(0xFF8E8E8E),
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Timestamp ───────────────────────────────────────
  Widget _buildTimestamp(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Text(
        timeago.format(widget.post.createdAt).toUpperCase(),
        style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E8E), letterSpacing: 0.5),
      ),
    );
  }

  void _showComments(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.72) : Colors.white.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                Expanded(
                  child: CommentsPage(
                    postId: widget.post.id,
                    post: widget.post,
                    isBottomSheet: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPostOptions(BuildContext context) async {
    final currentUser = ref.read(authProvider).user;
    final isOwner = currentUser?.id == widget.post.userId || widget.post.isOwnPost;

    final menuContext = MenuContext(
      contentId: widget.post.id,
      contentType: MenuContentType.post,
      relationship: isOwner ? MenuRelationship.owner : MenuRelationship.following,
      authorUsername: widget.post.username,
      authorId: widget.post.userId,
      authorAvatarUrl: widget.post.userAvatar,
      isSaved: _isSaved,
      isPinned: widget.post.isPinned,
      isVerified: widget.post.isVerified,
      commentsEnabled: !widget.post.commentsDisabled,
      hasLikeCount: !widget.post.hideLikesCount,
      canDelete: isOwner,
      canEdit: isOwner,
    );

    InstagramMenu.show(
      context,
      menuContext: menuContext,
      onAction: _handleMenuAction,
    );
  }

  Future<void> _handleMenuAction(MenuAction action) async {
    switch (action.type) {
      case MenuActionType.copyLink:
        Clipboard.setData(ClipboardData(text: 'https://instagram.com/p/${widget.post.id}'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard')),
        );
        break;
      case MenuActionType.saveCollection:
      case MenuActionType.unsave:
        _handleSave();
        break;
      case MenuActionType.delete:
        try {
          await ref.read(feedProvider.notifier).deletePost(widget.post.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post deleted')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete post: $e')),
            );
          }
        }
        break;
      case MenuActionType.pin:
      case MenuActionType.unpin:
        final newPinned = action.type == MenuActionType.pin;
        try {
          await ref.read(postServiceProvider).updatePost(
            postId: widget.post.id,
            data: {'isPinned': newPinned},
          );
          ref.read(feedProvider.notifier).updatePostInFeed(
            widget.post.id,
            (p) => p.copyWith(isPinned: newPinned),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(newPinned ? 'Post pinned to profile' : 'Post unpinned from profile')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update pin status: $e')),
            );
          }
        }
        break;
      case MenuActionType.archive:
        try {
          await ref.read(postServiceProvider).updatePost(
            postId: widget.post.id,
            data: {'isArchived': true},
          );
          ref.read(feedProvider.notifier).removePostLocally(widget.post.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post archived')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to archive post: $e')),
            );
          }
        }
        break;
      case MenuActionType.edit:
        final editController = TextEditingController(text: widget.post.caption);
        showCupertinoDialog(
          context: context,
          builder: (dialogCtx) => CupertinoAlertDialog(
            title: const Text('Edit Caption'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: CupertinoTextField(
                controller: editController,
                maxLines: 4,
                placeholder: 'Write a caption...',
                placeholderStyle: const TextStyle(color: CupertinoColors.placeholderText),
                style: TextStyle(color: Theme.of(dialogCtx).brightness == Brightness.dark ? Colors.white : Colors.black),
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Save'),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  final newCaption = editController.text;
                  try {
                    await ref.read(postServiceProvider).updatePost(
                      postId: widget.post.id,
                      data: {'caption': newCaption},
                    );
                    ref.read(feedProvider.notifier).updatePostInFeed(
                      widget.post.id,
                      (p) => p.copyWith(caption: newCaption),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post updated')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update post: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
        break;
      case MenuActionType.hideLikeCount:
        final newHide = !widget.post.hideLikesCount;
        try {
          await ref.read(postServiceProvider).updatePost(
            postId: widget.post.id,
            data: {'hideLikesCount': newHide},
          );
          ref.read(feedProvider.notifier).updatePostInFeed(
            widget.post.id,
            (p) => p.copyWith(hideLikesCount: newHide),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(newHide ? 'Likes hidden to others' : 'Likes visible to others')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update like settings: $e')),
            );
          }
        }
        break;
      case MenuActionType.turnOffComments:
      case MenuActionType.turnOnComments:
        final newCommentsDisabled = action.type == MenuActionType.turnOffComments;
        try {
          await ref.read(postServiceProvider).updatePost(
            postId: widget.post.id,
            data: {'commentsDisabled': newCommentsDisabled},
          );
          ref.read(feedProvider.notifier).updatePostInFeed(
            widget.post.id,
            (p) => p.copyWith(commentsDisabled: newCommentsDisabled),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(newCommentsDisabled ? 'Commenting turned off' : 'Commenting turned on')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update commenting settings: $e')),
            );
          }
        }
        break;
      case MenuActionType.qrCode:
        showDialog(
          context: context,
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'QR Code',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '@${widget.post.username}\'s post',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 200,
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF58529)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          size: 150,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CupertinoButton(
                      color: const Color(0xFF0095F6),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Save to Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        break;
      case MenuActionType.unfollow:
        try {
          await ref.read(followProvider(widget.post.userId).notifier).toggleFollow();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unfollowed @${widget.post.username}')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to unfollow: $e')),
            );
          }
        }
        break;
      case MenuActionType.report:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thanks for your feedback.')),
        );
        break;
      case MenuActionType.hide:
        ref.read(feedProvider.notifier).removePostLocally(widget.post.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post hidden')),
        );
        break;
      case MenuActionType.notInterested:
        try {
          await ref.read(postServiceProvider).recordInteraction(
            contentId: widget.post.id,
            contentType: 'post',
            action: 'not_interested',
            authorId: widget.post.userId,
          );
        } catch (e) {
          // Silent fallback
        }

        ref.read(notInterestedProvider.notifier).addPost({
          'id': widget.post.id,
          'username': widget.post.username,
          'caption': widget.post.caption,
          'thumbnailUrl': widget.post.mediaFiles.isNotEmpty ? widget.post.mediaFiles.first.thumbnailUrl : '',
          'mediaType': widget.post.mediaFiles.isNotEmpty ? widget.post.mediaFiles.first.mediaType : 'image',
          'userId': widget.post.userId,
        });

        ref.read(feedProvider.notifier).removePostLocally(widget.post.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('We\'ll show fewer posts like this')),
          );
        }
        break;
      case MenuActionType.whyYouSeeing:
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Why you\'re seeing this post'),
            content: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '• This post is popular in your region.\n'
                '• You follow or interact with content similar to @${widget.post.username}.\n'
                '• You recently spent time looking at related hashtags.',
                textAlign: TextAlign.left,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Done'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
        break;
      case MenuActionType.about:
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text('About @${widget.post.username}'),
            content: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'To help keep our community authentic, we show information about accounts on Instagram.\n\n'
                '• Date Joined: ${widget.post.createdAt.year}\n'
                '• Account Status: Active\n'
                '• Verified status: ${widget.post.isVerified ? "Verified Badge" : "Not Verified"}',
                textAlign: TextAlign.left,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Close'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
        break;
      default:
        break;
    }
  }
}

class LikeParticles extends StatefulWidget {
  final Offset position;

  const LikeParticles({super.key, required this.position});

  @override
  State<LikeParticles> createState() => _LikeParticlesState();
}

class _LikeParticlesState extends State<LikeParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ParticleData> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    final random = math.Random();
    for (int i = 0; i < 6; i++) {
      _particles.add(_ParticleData(
        angle: (random.nextDouble() * 2 - 1) * 0.5 - 1.57, // Upwards range
        velocity: 2.0 + random.nextDouble() * 2.0,
        size: 10.0 + random.nextDouble() * 10.0,
      ));
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: _particles.map((p) {
            final t = _controller.value;
            final dx = p.velocity * 100 * t * math.cos(p.angle);
            final dy = p.velocity * 100 * t * math.sin(p.angle);
            final opacity = (1.0 - t).clamp(0.0, 1.0);
            
            return Positioned(
              left: widget.position.dx + dx,
              top: widget.position.dy + dy,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: 0.5 + t * 0.5,
                  child: Container(
                    width: p.size,
                    height: p.size,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(204),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ParticleData {
  final double angle;
  final double velocity;
  final double size;

  _ParticleData({required this.angle, required this.velocity, required this.size});
}
