// lib/features/home/presentation/pages/home_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/router/main_shell.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import 'package:instagram_clinet/features/notifications/presentation/providers/notification_provider.dart';
import '../../../post/presentation/providers/feed_provider.dart';
import '../../../post/presentation/widgets/post_card.dart';
import '../../../story/presentation/providers/story_provider.dart';
import '../../../story/presentation/widgets/stories_bar.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const HomePageContent();
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
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    // Listen for scroll-to-top signal from MainShell
    ref.listen(homeScrollSignalProvider, (prev, next) {
      if (next > (prev ?? 0) && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuart,
        );
      }
    });

    return Material(
      type: MaterialType.transparency,
      child: CupertinoPageScaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ─── Top Navigation Bar ──────────────────────────
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 16,
            toolbarHeight: 52,
            title: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF833AB4), // Purple
                  Color(0xFFFD1D1D), // Red
                  Color(0xFFFCAF45), // Orange
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'Instagram',
                style: TextStyle(
                  fontFamily: 'Billabong',
                  fontSize: 32,
                  color: Colors.white,
                ),
              ),
            ),
            actions: [
              BouncyTap(
                onTap: () => context.push(AppRoutes.createPost),
                child: Icon(
                  PhosphorIcons.plusSquare(PhosphorIconsStyle.bold),
                  color: isDark ? Colors.white : Colors.black,
                  size: 26,
                ),
              ),
              const SizedBox(width: 18),
              _buildNavIcon(
                icon: PhosphorIcons.heart(PhosphorIconsStyle.bold),
                onTap: () => context.push(AppRoutes.notifications),
                badgeCount: ref.watch(unreadNotificationsCountProvider),
                isDark: isDark,
              ),
              const SizedBox(width: 18),
              _buildNavIcon(
                icon: PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.bold),
                onTap: () => context.push(AppRoutes.messages),
                badgeCount: ref.watch(dmUnreadCountProvider),
                isDark: isDark,
              ),
              const SizedBox(width: 16),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.33),
              child: Container(
                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFDBDBDB),
                height: 0.33,
              ),
            ),
          ),

          // ─── Refresh Control ─────────────────────────────
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await Future.wait([
                ref.read(feedProvider.notifier).refreshFeed(),
                ref.read(storyFeedProvider.notifier).loadStories(),
              ]);
            },
          ),

          // ─── Stories Section ─────────────────────────────
          // Reduced distance by applying a small negative translation
          const SliverToBoxAdapter(
            child: StoriesBar(),
          ),

          // ─── Feed Separator ──────────────────────────────
          SliverToBoxAdapter(
            child: Divider(
              height: 0.33,
              thickness: 0.33,
              color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFDBDBDB),
            ),
          ),

          // ─── Post List ───────────────────────────────────
          if (feedState.isLoading && feedState.posts.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (feedState.isEmptyFeed)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('No posts yet')),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == feedState.posts.length) {
                    if (feedState.hasMore) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: CupertinoActivityIndicator(),
                      );
                    }
                    return const SizedBox(height: 50);
                  }

                  final post = feedState.posts[index];
                  return PostCard(key: ValueKey(post.id), post: post);
                },
                childCount: feedState.posts.length + 1,
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildNavIcon({
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
    required bool isDark,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            icon,
            size: 24,
            color: isDark ? Colors.white : Colors.black,
          ),
          if (badgeCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3040),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.black : Colors.white,
                    width: 1.5,
                  ),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
