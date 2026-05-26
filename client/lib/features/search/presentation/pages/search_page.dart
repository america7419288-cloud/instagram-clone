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
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../../shared/widgets/user_story_avatar.dart';
import '../../../follow/data/repositories/presentation/providers/widgets/follow_button.dart';
import 'providers/search_provider.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        ref.read(searchProvider).showExplore) {
      ref.read(searchProvider.notifier).loadMoreExplore();
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

  Widget _buildExploreGrid(SearchState state) {
    return RefreshIndicator(
      onRefresh: () async => ref.read(searchProvider.notifier).refreshExplore(),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: StaggeredGrid.count(
              crossAxisCount: 3,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              children: List.generate(state.explorePostsGrid.length, (index) {
                // IOS Pattern: 1 large 2x2 every 18 tiles
                final int pos = index % 18;
                int crossCount = 1;
                int mainCount = 1;
                if (pos == 2 || pos == 11) {
                  crossCount = 2;
                  mainCount = 2;
                }
                return StaggeredGridTile.count(
                  crossAxisCellCount: crossCount,
                  mainAxisCellCount: mainCount,
                  child: _ExploreItem(post: state.explorePostsGrid[index]),
                );
              }),
            ),
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

class _ExploreItem extends StatefulWidget {
  final Map<String, dynamic> post;
  const _ExploreItem({required this.post});

  @override
  State<_ExploreItem> createState() => _ExploreItemState();
}

class _ExploreItemState extends State<_ExploreItem> {
  OverlayEntry? _peakOverlay;

  void _showPeak() {
    if (_peakOverlay != null) return;
    HapticFeedback.heavyImpact();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    _peakOverlay = OverlayEntry(
      builder: (ctx) => Positioned.fill(
        child: Material(
          color: Colors.black.withOpacity(0.4),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Center(
              child: Container(
                width: size.width * 0.88,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header: Avatar + Username
                    ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                        backgroundImage: widget.post['profile_pic_url'] != null && widget.post['profile_pic_url'].isNotEmpty
                            ? NetworkImage(widget.post['profile_pic_url'])
                            : null,
                        child: widget.post['profile_pic_url'] == null || widget.post['profile_pic_url'].isEmpty
                            ? Icon(LucideIcons.user, size: 16, color: isDark ? Colors.white54 : Colors.black45)
                            : null,
                      ),
                      title: Text(
                        widget.post['username'] ?? 'username',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    // Post Image/Video Preview
                    ClipRRect(
                      borderRadius: widget.post['media_type'] == 'video' 
                          ? BorderRadius.zero 
                          : const BorderRadius.vertical(bottom: Radius.circular(0)),
                      child: widget.post['media_type'] == 'video' && widget.post['video_url'] != null
                          ? _PeakVideoPlayer(videoUrl: widget.post['video_url'])
                          : CachedNetworkImage(
                              imageUrl: widget.post['thumbnail_url'] ?? '',
                              fit: BoxFit.cover,
                              height: size.height * 0.45,
                              width: double.infinity,
                            ),
                    ),
                    // Quick Action Icons
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Icon(LucideIcons.heart, size: 24, color: isDark ? Colors.white : Colors.black),
                          Icon(LucideIcons.user_round, size: 24, color: isDark ? Colors.white : Colors.black),
                          Icon(LucideIcons.send, size: 24, color: isDark ? Colors.white : Colors.black),
                          Icon(LucideIcons.bookmark, size: 24, color: isDark ? Colors.white : Colors.black),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_peakOverlay!);
  }

  void _hidePeak() {
    if (_peakOverlay != null) {
      _peakOverlay!.remove();
      _peakOverlay = null;
    }
  }

  @override
  void dispose() {
    _hidePeak();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _showPeak(),
      onLongPressEnd: (_) => _hidePeak(),
      onLongPressUp: () => _hidePeak(),
      onLongPressCancel: () => _hidePeak(),
      onTap: () => context.push('/post/${widget.post['id']}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: widget.post['thumbnail_url'] ?? '',
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[200]),
          ),
          if (widget.post['media_type'] == 'video')
            const Positioned(top: 8, right: 8, child: Icon(LucideIcons.play, color: Colors.white, size: 18)),
        ],
      ),
    );
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
