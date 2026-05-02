// lib/features/home/presentation/pages/home_page.dart
// COMPLETE UPDATED FILE

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../post/presentation/providers/feed_provider.dart';
import '../../../post/presentation/widgets/post_card.dart';
import '../../../story/presentation/widgets/stories_bar.dart';
import '../../../story/presentation/providers/story_provider.dart';
import '../../../notifications/presentation/pages/providers/notification_provider.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../../shared/widgets/shimmer_widget.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(body: HomePageContent());
  }
}

class HomePageContent extends ConsumerStatefulWidget {
  const HomePageContent({super.key});

  @override
  ConsumerState<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends ConsumerState<HomePageContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh both feed and stories
          await Future.wait<void>([
            ref.read(feedProvider.notifier).refreshFeed(),
            ref.read(storyFeedProvider.notifier).loadStories(),
            ref.read(notificationProvider.notifier).loadUnreadCount(),
          ]);
        },
        color: AppColors.primary,
        child: _buildBody(feedState),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final unreadCount = ref.watch(unreadCountProvider);

    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: ShaderMask(
        shaderCallback: (bounds) => AppColors.instagramGradient.createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        ),
        child: const Text(
          'Instagram',
          style: TextStyle(
            fontSize: 28,
            fontFamily: 'Billabong',
            color: Colors.white,
          ),
        ),
      ),
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => context.go(AppRoutes.notifications),
              icon: const Icon(
                Icons.favorite_border,
                color: AppColors.textPrimary,
                size: 26,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => context.go(AppRoutes.messages),
              icon: const Icon(
                Icons.send_outlined,
                color: AppColors.textPrimary,
                size: 26,
              ),
            ),
            // DM unread badge
            Consumer(
              builder: (context, ref, _) {
                final dmCount = ref.watch(dmUnreadCountProvider);
                if (dmCount == 0) return const SizedBox.shrink();
                return Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        dmCount > 9 ? '9+' : '$dmCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody(FeedState feedState) {
    if (feedState.isLoading) {
      return const _LoadingFeed();
    }

    if (feedState.errorMessage != null && feedState.posts.isEmpty) {
      return _ErrorState(
        message: feedState.errorMessage!,
        onRetry: () => ref.read(feedProvider.notifier).loadFeed(),
      );
    }

    if (feedState.isEmptyFeed || feedState.posts.isEmpty) {
      return _EmptyFeedState();
    }

    return _buildFeedList(feedState);
  }

  Widget _buildFeedList(FeedState feedState) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Stories bar (REAL data now)
        const SliverToBoxAdapter(
          child: Column(
            children: [
              StoriesBar(), // ⭐ Real stories
              Divider(height: 1, color: AppColors.border),
            ],
          ),
        ),

        // Posts
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index == feedState.posts.length) {
              if (feedState.isLoadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }
              if (!feedState.hasMore) {
                return const _EndOfFeedMessage();
              }
              return const SizedBox.shrink();
            }

            final post = feedState.posts[index];
            return Column(
              children: [
                PostCard(key: ValueKey(post.id), post: post),
                const Divider(height: 1, color: AppColors.border),
              ],
            );
          }, childCount: feedState.posts.length + 1),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

// ─── LOADING STATE ────────────────────────────────────────────
class _LoadingFeed extends StatelessWidget {
  const _LoadingFeed();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          StoryBarSkeleton(),
          Divider(height: 1, color: AppColors.border),
          FeedSkeleton(),
        ],
      ),
    );
  }
}

// ─── ERROR STATE ──────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_outlined,
              size: 60,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load feed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EMPTY FEED ───────────────────────────────────────────────
class _EmptyFeedState extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textPrimary, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 50,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to Instagram',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Follow people to see their photos and videos here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: ElevatedButton(
                onPressed: () => context.go(AppRoutes.search),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Find People to Follow',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── END OF FEED ──────────────────────────────────────────────
class _EndOfFeedMessage extends StatelessWidget {
  const _EndOfFeedMessage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: AppColors.textSecondary,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "You're all caught up",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'You have seen all new posts\nfrom the past 3 days.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
