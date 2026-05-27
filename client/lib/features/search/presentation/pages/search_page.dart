// lib/features/search/presentation/pages/search_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../../shared/widgets/user_story_avatar.dart';
import '../../../follow/data/repositories/presentation/providers/widgets/follow_button.dart';
import 'providers/search_provider.dart';
import '../../../post/data/repositories/post_service.dart';
import '../../../post/presentation/providers/feed_provider.dart';
import '../../../share/presentation/share_sheet.dart';
import '../../../share/models/share_content.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;
  int _selectedTabIndex = 1; // Default to Accounts

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus != _isSearching) {
        setState(() => _isSearching = _searchFocus.hasFocus);
      }
    });
  }

  OverlayEntry? _peekOverlayEntry;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    _hidePeekPreview();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        ref.read(searchProvider).showExplore) {
      ref.read(searchProvider.notifier).loadMoreExplore();
    }
  }

  void _showPeekPreview(Map<String, dynamic> post, Rect rect) {
    if (_peekOverlayEntry != null) return;
    HapticFeedback.mediumImpact();

    _peekOverlayEntry = OverlayEntry(
      builder: (context) => PeekPreviewOverlay(
        post: post,
        originRect: rect,
        onDismiss: _hidePeekPreview,
        onNavigateToPost: () {
          context.push('/post/${post['id']}');
        },
        ref: ref,
      ),
    );
    Overlay.of(context).insert(_peekOverlayEntry!);
  }

  void _hidePeekPreview() {
    if (_peekOverlayEntry != null) {
      _peekOverlayEntry!.remove();
      _peekOverlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // ─── IOS SEARCH BAR ────────────────────────────
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_isSearching ? 88 : 52),
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkInputBackground : AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          onChanged: (v) => ref.read(searchProvider.notifier).onQueryChanged(v),
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Search',
                            hintStyle: const TextStyle(color: AppColors.textSecondary),
                            prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textSecondary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ),
                    if (_isSearching)
                      CupertinoButton(
                        padding: const EdgeInsets.only(left: 12),
                        onPressed: () {
                          _searchFocus.unfocus();
                          _searchController.clear();
                          setState(() => _isSearching = false);
                          ref.read(searchProvider.notifier).clearSearch();
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.primary, fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_isSearching) _buildSearchTabs(isDark),
          ],
        ),
      ),

      body: _isSearching
          ? (searchState.showResults ? _buildSearchResults(searchState, isDark) : _buildRecentHistory(searchState, isDark))
          : _buildExploreGrid(searchState),
    );
  }

  Widget _buildSearchTabs(bool isDark) {
    final tabs = ['Top', 'Accounts', 'Audio', 'Tags', 'Places', 'Reels'];
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkSeparator : AppColors.separator, width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedTabIndex;
          return BouncyTap(
            onTap: () {
              setState(() => _selectedTabIndex = index);
              // In future: trigger new search based on tab type
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: isSelected ? Border(bottom: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5)) : null,
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? (isDark ? Colors.white : Colors.black) : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExploreShimmer(bool isDark) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return const _ShimmerPlaceholder();
            },
            childCount: 18,
          ),
          gridDelegate: _InstagramGridDelegate(),
        ),
      ],
    );
  }

  Widget _buildExploreGrid(SearchState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show beautiful iOS-style shimmer grid when empty and loading
    if (state.explorePostsGrid.isEmpty && state.isLoadingExplore) {
      return _buildExploreShimmer(isDark);
    }

    return RefreshIndicator(
      onRefresh: () async => ref.read(searchProvider.notifier).refreshExplore(),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= state.explorePostsGrid.length) return null;
                final post = state.explorePostsGrid[index];
                final pattern = index % 6;
                return _ExploreGridItem(
                  post: post,
                  isLarge: pattern == 0 || pattern == 5,
                  onTap: () => context.push('/post/${post['id']}'),
                  onHold: (rect) => _showPeekPreview(post, rect),
                );
              },
              childCount: state.explorePostsGrid.length,
            ),
            gridDelegate: _InstagramGridDelegate(),
          ),
          if (state.isLoadingExplore)
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.all(20), child: CupertinoActivityIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentHistory(SearchState state, bool isDark) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              BouncyTap(
                onTap: () => ref.read(searchProvider.notifier).clearRecentSearches(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('See All', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        ...state.recentSearches.map((s) => BouncyTap(
              onTap: () => _searchController.text = s,
              child: ListTile(
                leading: const CircleAvatar(radius: 22, backgroundColor: AppColors.border, child: Icon(LucideIcons.search, size: 20, color: Colors.grey)),
                title: Text(s, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(LucideIcons.x, size: 14, color: Colors.grey),
              ),
            )),
      ],
    );
  }

  Widget _buildSearchResults(SearchState state, bool isDark) {
    if (state.isLoadingResults) return const Center(child: CupertinoActivityIndicator());

    if (_selectedTabIndex != 1) {
      final tabs = ['Top', 'Accounts', 'Audio', 'Tags', 'Places', 'Reels'];
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.search, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Search for ${tabs[_selectedTabIndex]}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming soon in the next update.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (state.userResults.isEmpty) {
      return const Center(child: Text('No accounts found', style: TextStyle(color: AppColors.textSecondary)));
    }

    return ListView.builder(
      itemCount: state.userResults.length,
      itemBuilder: (context, index) {
        final user = state.userResults[index];
        return _UserResultTile(user: user);
      },
    );
  }
}

class _ExploreGridItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isLarge;
  final VoidCallback onTap;
  final Function(Rect) onHold;

  const _ExploreGridItem({
    required this.post,
    required this.isLarge,
    required this.onTap,
    required this.onHold,
  });

  @override
  State<_ExploreGridItem> createState() => _ExploreGridItemState();
}

class _ExploreGridItemState extends State<_ExploreGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScale;
  final GlobalKey _itemKey = GlobalKey();
  bool _isLongPressing = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Rect _getItemRect() {
    final renderBox = _itemKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Rect.zero;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideo = widget.post['media_type'] == 'video';
    final thumbnailUrl = widget.post['thumbnail_url'] ?? '';

    return GestureDetector(
      key: _itemKey,
      onTap: _isLongPressing ? null : widget.onTap,
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onLongPressStart: (_) {
        setState(() => _isLongPressing = true);
        HapticFeedback.mediumImpact();
        final rect = _getItemRect();
        widget.onHold(rect);
      },
      onLongPressEnd: (_) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            setState(() => _isLongPressing = false);
          }
        });
      },
      child: AnimatedBuilder(
        animation: _pressScale,
        builder: (_, child) => Transform.scale(
          scale: _pressScale.value,
          child: child,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail Image
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEBEBEB),
                ),
                errorWidget: (context, url, error) => Container(
                  color: isDark ? Colors.grey[900] : Colors.grey[300],
                  child: const Icon(LucideIcons.image_off, color: Colors.grey),
                ),
              ),
            ),
            // Carousel Indicator
            if (widget.post['media_urls'] is List && (widget.post['media_urls'] as List).length > 1)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  LucideIcons.layers,
                  color: Colors.white,
                  size: 16,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            // Video Indicator
            if (isVideo)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  LucideIcons.play,
                  color: Colors.white,
                  size: 16,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── PEEK PREVIEW OVERLAY ───────────────────────────────────────
class PeekPreviewOverlay extends StatefulWidget {
  final Map<String, dynamic> post;
  final Rect originRect;
  final VoidCallback onDismiss;
  final VoidCallback onNavigateToPost;
  final WidgetRef ref;

  const PeekPreviewOverlay({
    super.key,
    required this.post,
    required this.originRect,
    required this.onDismiss,
    required this.onNavigateToPost,
    required this.ref,
  });

  @override
  State<PeekPreviewOverlay> createState() => _PeekPreviewOverlayState();
}

class _PeekPreviewOverlayState extends State<PeekPreviewOverlay>
    with TickerProviderStateMixin {
  late AnimationController _backdropController;
  late AnimationController _cardController;
  
  late Animation<double> _backdropBlur;
  late Animation<double> _backdropOpacity;
  late Animation<double> _cardScale;
  late Animation<double> _cardOpacity;
  late Animation<BorderRadius?> _cardRadius;

  double _swipeDeltaX = 0;
  bool _showActionButtons = false;
  bool _isActionsVisible = false;

  late List<AnimationController> _actionControllers;
  late List<Animation<double>> _actionSlides;
  late List<Animation<double>> _actionOpacities;

  late bool _isLiked;
  late int _likeCount;

  late Rect _targetRect;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post['is_liked'] == true;
    _likeCount = widget.post['likes_count'] ?? widget.post['likeCount'] ?? 0;

    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screenSize = view.physicalSize / view.devicePixelRatio;

    final previewWidth = screenSize.width * 0.88;
    final previewHeight = previewWidth * 1.25;
    _targetRect = Rect.fromLTWH(
      (screenSize.width - previewWidth) / 2,
      (screenSize.height - previewHeight) / 2 - 30,
      previewWidth,
      previewHeight,
    );

    _setupAnimations();
    _playOpenAnimation();
  }

  void _setupAnimations() {
    _backdropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _backdropBlur = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _backdropController, curve: Curves.easeOut),
    );
    _backdropOpacity = Tween<double>(begin: 0, end: 0.65).animate(
      CurvedAnimation(parent: _backdropController, curve: Curves.easeOut),
    );

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cardScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.elasticOut),
    );
    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _cardRadius = BorderRadiusTween(
      begin: BorderRadius.circular(4),
      end: BorderRadius.circular(16),
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _actionControllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
      ),
    );

    _actionSlides = _actionControllers
        .map((c) => Tween<double>(begin: 60, end: 0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeOutBack),
            ))
        .toList();

    _actionOpacities = _actionControllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: c, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
            ))
        .toList();
  }

  Future<void> _playOpenAnimation() async {
    _backdropController.forward();
    await Future.delayed(const Duration(milliseconds: 50));
    _cardController.forward();
  }

  Future<void> _playCloseAnimation() async {
    for (final c in _actionControllers.reversed) {
      c.reverse();
      await Future.delayed(const Duration(milliseconds: 30));
    }
    await Future.wait([
      _backdropController.reverse(),
      _cardController.reverse(),
    ]);
    widget.onDismiss();
  }

  void _handleHorizontalDrag(DragUpdateDetails details) {
    setState(() {
      _swipeDeltaX += details.delta.dx;
      _swipeDeltaX = _swipeDeltaX.clamp(-140.0, 20.0);
    });

    if (_swipeDeltaX < -60 && !_isActionsVisible) {
      _isActionsVisible = true;
      setState(() => _showActionButtons = true);
      _staggerActionButtons();
    }

    if (_swipeDeltaX > -30 && _isActionsVisible) {
      _isActionsVisible = false;
      setState(() => _showActionButtons = false);
      for (final c in _actionControllers) {
        c.reverse();
      }
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (_swipeDeltaX < -80 || velocity < -400) {
      setState(() => _swipeDeltaX = -120);
      if (!_isActionsVisible) {
        _isActionsVisible = true;
        setState(() => _showActionButtons = true);
        _staggerActionButtons();
      }
    } else {
      setState(() => _swipeDeltaX = 0);
      if (_isActionsVisible) {
        _isActionsVisible = false;
        for (final c in _actionControllers) {
          c.reverse();
        }
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _showActionButtons = false);
          }
        });
      }
    }
  }

  void _staggerActionButtons() {
    for (int i = 0; i < _actionControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        if (mounted) {
          _actionControllers[i].forward();
        }
      });
    }
  }

  void _handleLike() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final postId = widget.post['id'];
      if (_isLiked) {
        await widget.ref.read(postServiceProvider).likePost(postId);
      } else {
        await widget.ref.read(postServiceProvider).unlikePost(postId);
      }
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
    }

    await Future.delayed(const Duration(milliseconds: 400));
    _playCloseAnimation();
  }

  void _handleComment() {
    _playCloseAnimation();
    context.push('/post/${widget.post['id']}/comments', extra: widget.post);
  }

  void _handleShare() {
    _playCloseAnimation();
    ShareSheet.show(
      context,
      content: ShareContent(
        id: widget.post['id'],
        type: widget.post['media_type'] == 'video' ? ShareContentType.reel : ShareContentType.post,
        authorUsername: widget.post['username'],
        thumbnailUrl: widget.post['thumbnail_url'],
        caption: widget.post['caption'],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _playCloseAnimation,
      child: AnimatedBuilder(
        animation: Listenable.merge([_backdropController, _cardController]),
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _backdropBlur.value,
                    sigmaY: _backdropBlur.value,
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(_backdropOpacity.value),
                  ),
                ),
              ),
              _buildPreviewCard(),
              if (_showActionButtons) _buildActionButtons(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreviewCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      left: _targetRect.left,
      top: _targetRect.top,
      width: _targetRect.width,
      height: _targetRect.height,
      child: Transform.scale(
        scale: _cardScale.value,
        child: Transform.translate(
          offset: Offset(_swipeDeltaX, 0),
          child: Opacity(
            opacity: _cardOpacity.value,
            child: GestureDetector(
              onTap: () {
                _playCloseAnimation();
                widget.onNavigateToPost();
              },
              onHorizontalDragUpdate: _handleHorizontalDrag,
              onHorizontalDragEnd: _handleHorizontalDragEnd,
              child: ClipRRect(
                borderRadius: _cardRadius.value ?? BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: _cardRadius.value ?? BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: -4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCardHeader(isDark),
                      _buildCardMedia(),
                      _buildCardInlineActions(),
                      _buildCardLikes(),
                      _buildCardCaption(),
                      _buildCardCommentsPreview(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(bool isDark) {
    final avatarUrl = widget.post['profile_pic_url'];
    final username = widget.post['username'] ?? 'username';
    final isVerified = widget.post['is_verified'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            backgroundColor: Colors.grey[300],
            child: avatarUrl == null || avatarUrl.isEmpty
                ? const Icon(LucideIcons.user, size: 16, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Text(
                  username,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, color: Color(0xFF0095F6), size: 13),
                ],
              ],
            ),
          ),
          Icon(LucideIcons.ellipsis, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _playCloseAnimation,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardMedia() {
    final isVideo = widget.post['media_type'] == 'video';
    final videoUrl = widget.post['video_url'];
    final thumbnailUrl = widget.post['thumbnail_url'] ?? '';

    return AspectRatio(
      aspectRatio: 1.0,
      child: isVideo && videoUrl != null
          ? _PeakVideoPlayer(videoUrl: videoUrl)
          : CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
            ),
    );
  }

  Widget _buildCardInlineActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _LikeActionButton(
            isLiked: _isLiked,
            onTap: _handleLike,
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: _handleComment,
            child: const Icon(LucideIcons.message_circle, size: 24),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: _handleShare,
            child: Transform.rotate(
              angle: -0.4,
              child: const Icon(LucideIcons.send, size: 22),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: const Icon(LucideIcons.bookmark, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildCardLikes() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Text(
        _likeCount > 0 ? '$_likeCount likes' : 'Be the first to like this',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildCardCaption() {
    final username = widget.post['username'] ?? 'username';
    final caption = widget.post['caption'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: '$username ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              ),
            ),
            TextSpan(
              text: caption,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardCommentsPreview() {
    final commentCount = widget.post['comments_count'] ?? widget.post['commentCount'] ?? 0;
    if (commentCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: GestureDetector(
        onTap: _handleComment,
        child: Text(
          'View all $commentCount comments',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final actions = [
      _PreviewActionButton(
        icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: _isLiked ? const Color(0xFFED4956) : Colors.white,
        backgroundColor: _isLiked ? const Color(0xFFED4956).withOpacity(0.2) : Colors.white.withOpacity(0.15),
        label: 'Like',
        onTap: _handleLike,
      ),
      _PreviewActionButton(
        icon: LucideIcons.message_circle,
        color: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.15),
        label: 'Comment',
        onTap: _handleComment,
      ),
      _PreviewActionButton(
        icon: LucideIcons.send,
        color: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.15),
        label: 'Share',
        onTap: _handleShare,
        rotateAngle: -0.4,
      ),
    ];

    return Positioned(
      right: 16,
      top: _targetRect.top + (_targetRect.height / 2) - (actions.length * 68) / 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: actions.asMap().entries.map((entry) {
          final index = entry.key;
          final action = entry.value;
          return AnimatedBuilder(
            animation: _actionControllers[index],
            builder: (_, child) => Transform.translate(
              offset: Offset(_actionSlides[index].value, 0),
              child: Opacity(
                opacity: _actionOpacities[index].value,
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: action,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _backdropController.dispose();
    _cardController.dispose();
    for (final c in _actionControllers) {
      c.dispose();
    }
    super.dispose();
  }
}

// ─── ACTION BUTTONS FOR PREVIEW ──────────────────────────────────
class _LikeActionButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;

  const _LikeActionButton({
    required this.isLiked,
    required this.onTap,
  });

  @override
  State<_LikeActionButton> createState() => _LikeActionButtonState();
}

class _LikeActionButtonState extends State<_LikeActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Transform.scale(
          scale: _scaleAnim.value,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(widget.isLiked),
              size: 26,
              color: widget.isLiked ? const Color(0xFFED4956) : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _PreviewActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String label;
  final VoidCallback onTap;
  final double rotateAngle;

  const _PreviewActionButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.label,
    required this.onTap,
    this.rotateAngle = 0,
  });

  @override
  State<_PreviewActionButton> createState() => _PreviewActionButtonState();
}

class _PreviewActionButtonState extends State<_PreviewActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _tapScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeInOut));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _tapController.forward(from: 0);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _tapScale,
        builder: (_, child) => Transform.scale(
          scale: _tapScale.value,
          child: child,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Transform.rotate(
                  angle: widget.rotateAngle,
                  child: Icon(
                    widget.icon,
                    color: widget.color,
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }
}

class _ShimmerPlaceholder extends StatelessWidget {
  const _ShimmerPlaceholder();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEBEBEB),
      highlightColor: isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5),
      child: Container(
        color: Colors.white,
      ),
    );
  }
}

// ─── INSTAGRAM GRID DELEGATE & LAYOUT ───────────────────────────────────────
class _InstagramGridDelegate extends SliverGridDelegate {
  static const double gap = 1.0;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    final smallSize = (width - gap * 2) / 3;
    final largeSize = smallSize * 2 + gap;

    return _InstagramGridLayout(
      width: width,
      smallSize: smallSize,
      largeSize: largeSize,
      gap: gap,
    );
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegate oldDelegate) => false;
}

class _InstagramGridLayout extends SliverGridLayout {
  final double width;
  final double smallSize;
  final double largeSize;
  final double gap;

  _InstagramGridLayout({
    required this.width,
    required this.smallSize,
    required this.largeSize,
    required this.gap,
  });

  @override
  double computeMaxScrollOffset(int childCount) {
    if (childCount == 0) return 0;
    final blocks = childCount ~/ 6;
    final remainder = childCount % 6;
    double offset = blocks * (largeSize * 2 + gap * 2);
    if (remainder > 0) {
      if (remainder <= 3) {
        offset += largeSize + gap;
      } else {
        offset += largeSize * 2 + gap * 2;
      }
    }
    return offset;
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final block = index ~/ 6;
    final posInBlock = index % 6;
    final blockOffset = block * (largeSize * 2 + gap * 2);

    switch (posInBlock) {
      case 0:
        return SliverGridGeometry(
          scrollOffset: blockOffset,
          crossAxisOffset: 0,
          mainAxisExtent: largeSize,
          crossAxisExtent: largeSize,
        );
      case 1:
        return SliverGridGeometry(
          scrollOffset: blockOffset,
          crossAxisOffset: largeSize + gap,
          mainAxisExtent: smallSize,
          crossAxisExtent: smallSize,
        );
      case 2:
        return SliverGridGeometry(
          scrollOffset: blockOffset + smallSize + gap,
          crossAxisOffset: largeSize + gap,
          mainAxisExtent: smallSize,
          crossAxisExtent: smallSize,
        );
      case 3:
        return SliverGridGeometry(
          scrollOffset: blockOffset + largeSize + gap,
          crossAxisOffset: 0,
          mainAxisExtent: smallSize,
          crossAxisExtent: smallSize,
        );
      case 4:
        return SliverGridGeometry(
          scrollOffset: blockOffset + largeSize + gap + smallSize + gap,
          crossAxisOffset: 0,
          mainAxisExtent: smallSize,
          crossAxisExtent: smallSize,
        );
      case 5:
        return SliverGridGeometry(
          scrollOffset: blockOffset + largeSize + gap,
          crossAxisOffset: smallSize + gap,
          mainAxisExtent: largeSize,
          crossAxisExtent: largeSize,
        );
      default:
        return SliverGridGeometry(
          scrollOffset: 0,
          crossAxisOffset: 0,
          mainAxisExtent: smallSize,
          crossAxisExtent: smallSize,
        );
    }
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    final block = (scrollOffset / (largeSize * 2 + gap * 2)).floor();
    return block * 6;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    final block = (scrollOffset / (largeSize * 2 + gap * 2)).ceil();
    return block * 6 + 5;
  }
}

class _UserResultTile extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserResultTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: () => context.push('/profile/${user['username']}'),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: UserStoryAvatar(
          userId: user['id'] ?? '',
          profilePicUrl: user['profile_pic_url'],
          username: user['username'],
          size: 44,
          showPresence: false,
          isClickable: true,
        ),
        title: Row(
          children: [
            Text(user['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (user['is_verified'] == true) ...[
              const SizedBox(width: 4),
              VerifiedBadge(size: 14),
            ],
          ],
        ),
        subtitle: Text(
          user['full_name'] ?? '',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        trailing: user['is_own_profile'] == true ? null : FollowButton(targetUserId: user['id'] ?? '', compact: true),
      ),
    );
  }
}

// ── Peak Video Player ───────────────────────────────────────
class _PeakVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _PeakVideoPlayer({required this.videoUrl});

  @override
  State<_PeakVideoPlayer> createState() => _PeakVideoPlayerState();
}

class _PeakVideoPlayerState extends State<_PeakVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller?.setLooping(true);
          _controller?.play();
        }
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (!_initialized) {
      return Container(
        height: size.height * 0.45,
        color: Colors.black12,
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }
    return SizedBox(
      height: size.height * 0.45,
      width: double.infinity,
      child: VideoPlayer(_controller!),
    );
  }
}
