// lib/features/search/presentation/pages/search_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../follow/data/repositories/presentation/providers/widgets/follow_button.dart';
import '../../../follow/data/repositories/presentation/providers/follow_provider.dart';
import 'providers/search_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController =
      TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

    return Scaffold(
      backgroundColor: AppColors.white,

      // ─── APP BAR WITH SEARCH ───────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: _buildSearchBar(searchState),
        automaticallyImplyLeading: false,
      ),

      // ─── BODY ──────────────────────────────────────────
      body: searchState.showResults
          ? _buildSearchResults(searchState)
          : _buildExplore(searchState),
    );
  }

  // ─── SEARCH BAR ────────────────────────────────────────────
  Widget _buildSearchBar(SearchState searchState) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (value) =>
            ref.read(searchProvider.notifier).onQueryChanged(value),
        onSubmitted: (value) {
          ref.read(searchProvider.notifier).submitSearch(value);
        },
        decoration: InputDecoration(
          hintText: 'Search users, hashtags...',
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textSecondary,
            size: 20,
          ),
          suffixIcon: searchState.query.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    ref.read(searchProvider.notifier).clearSearch();
                    _searchFocus.unfocus();
                  },
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  // ─── SEARCH RESULTS ────────────────────────────────────────
  Widget _buildSearchResults(SearchState searchState) {
    if (searchState.isLoadingResults) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (searchState.userResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 60,
              color: AppColors.border,
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "${searchState.query}"',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: searchState.userResults.length,
      itemBuilder: (context, index) {
        final user = searchState.userResults[index];
        return _UserSearchResult(
          user: user,
          onTap: () {
            ref.read(searchProvider.notifier).submitSearch(
                  user['username'] as String? ?? '',
                );
            context.push(
              '/profile/${user['username']}',
            );
          },
        );
      },
    );
  }

  // ─── EXPLORE (when no search query) ───────────────────────
  Widget _buildExplore(SearchState searchState) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // ─── RECENT SEARCHES ─────────────────────────────
        if (searchState.recentSearches.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRecentSearches(searchState),
          ),

        // ─── EXPLORE HEADER ──────────────────────────────
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Explore',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),

        // ─── EXPLORE GRID ────────────────────────────────
        searchState.isLoadingExplore &&
                searchState.explorePostsGrid.isEmpty
            ? const SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: _ExploreGrid(
                  posts: searchState.explorePostsGrid,
                ),
              ),

        // ─── LOAD MORE INDICATOR ─────────────────────────
        if (searchState.isLoadingExplore &&
            searchState.explorePostsGrid.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  // ─── RECENT SEARCHES ───────────────────────────────────────
  Widget _buildRecentSearches(SearchState searchState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => ref
                    .read(searchProvider.notifier)
                    .clearRecentSearches(),
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...searchState.recentSearches.map(
          (search) => ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.border.withOpacity(0.5),
              ),
              child: const Icon(
                Icons.history,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
            title: Text(
              search,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: GestureDetector(
              onTap: () => ref
                  .read(searchProvider.notifier)
                  .removeRecentSearch(search),
              child: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
            onTap: () {
              _searchController.text = search;
              ref
                  .read(searchProvider.notifier)
                  .onQueryChanged(search);
            },
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

// ─── USER SEARCH RESULT ─────────────────────────────────────
class _UserSearchResult extends ConsumerWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const _UserSearchResult({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = user['id'] as String? ?? '';
    final username = user['username'] as String? ?? '';
    final fullName = user['full_name'] as String? ?? '';
    final profilePicUrl = user['profile_pic_url'] as String?;
    final isVerified = user['is_verified'] as bool? ?? false;
    final isPrivate = user['is_private'] as bool? ?? false;
    final bio = user['bio'] as String? ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.border,
              ),
              child: ClipOval(
                child: profilePicUrl != null
                    ? CachedNetworkImage(
                        imageUrl: profilePicUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _defaultAvatar(username),
                      )
                    : _defaultAvatar(username),
              ),
            ),

            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                      if (isPrivate) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.lock,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ],
                  ),
                  if (fullName.isNotEmpty)
                    Text(
                      fullName,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  if (bio.isNotEmpty)
                    Text(
                      bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Follow button
            FollowButton(
              targetUserId: userId,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar(String username) {
    return Container(
      color: AppColors.border,
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── EXPLORE GRID ────────────────────────────────────────────
class _ExploreGrid extends StatelessWidget {
  final List<Map<String, dynamic>> posts;

  const _ExploreGrid({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SliverToBoxAdapter();

    // Build masonry-style grid
    // Pattern: [small, small, large] repeating
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= posts.length) return null;
          final post = posts[index];
          return _ExploreGridItem(post: post);
        },
        childCount: posts.length,
      ),
    );
  }
}

// ─── EXPLORE GRID ITEM ───────────────────────────────────────
class _ExploreGridItem extends StatelessWidget {
  final Map<String, dynamic> post;

  const _ExploreGridItem({required this.post});

  @override
  Widget build(BuildContext context) {
    final postId = post['id'] as String? ?? '';
    final thumbnailUrl = post['thumbnail_url'] as String?;
    final mediaType = post['media_type'] as String? ?? 'image';

    return GestureDetector(
      onTap: () => context.push('/post/$postId'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          thumbnailUrl != null
              ? CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.border,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.border,
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : Container(
                  color: AppColors.border,
                  child: const Icon(
                    Icons.image_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),

          // Video indicator
          if (mediaType == 'video')
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 20,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
