// lib/features/home/presentation/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/shimmer_widget.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../post/presentation/providers/feed_provider.dart';
import '../../../post/presentation/widgets/post_card.dart';
import '../../../story/presentation/providers/story_provider.dart';
import '../../../story/presentation/widgets/stories_bar.dart';

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
        _scrollController.position.maxScrollExtent - 500) {
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
          HapticFeedback.lightImpact();
          await Future.wait<void>([
            ref.read(feedProvider.notifier).refreshFeed(),
            ref.read(storyFeedProvider.notifier).loadStories(),
            ref.read(notificationProvider.notifier).loadUnreadCount(),
          ]);
        },
        color: AppColors.primary,
        displacement: 60,
        strokeWidth: 2.5,
        child: _buildBody(feedState),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider).asData?.value ?? 0;

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
            Consumer(
              builder: (context, ref, _) {
                final dmCount = ref.watch(dmUnreadCountProvider);
                if (dmCount == 0) {
                  return const SizedBox.shrink();
                }

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
    if (feedState.errorMessage != null && feedState.posts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ErrorView(
            message: feedState.errorMessage!,
            onRetry: () => ref.read(feedProvider.notifier).loadFeed(),
          ),
        ],
      );
    }

    if (feedState.isLoading && feedState.posts.isEmpty) {
      return const _LoadingFeed();
    }

    if (feedState.isEmptyFeed || feedState.posts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          StoriesBar(),
          SizedBox(height: 60),
          EmptyState.feed(),
        ],
      );
    }

    return _buildFeedList(feedState);
  }

  Widget _buildFeedList(FeedState feedState) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        const SliverToBoxAdapter(
          child: Column(
            children: [
              StoriesBar(),
              Divider(height: 1, color: AppColors.border),
            ],
          ),
        ),
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

class _LoadingFeed extends StatelessWidget {
  const _LoadingFeed();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
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
