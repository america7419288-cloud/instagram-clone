// lib/features/home/presentation/pages/home_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../shared/widgets/app_loader.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/router/main_shell.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../chat/presentation/providers/chat_notifiers.dart';
import 'package:instagram_client/features/notifications/presentation/providers/notification_provider.dart';
import '../../../post/presentation/providers/feed_provider.dart';
import '../../../post/presentation/widgets/post_card.dart';
import '../../../story/presentation/providers/story_provider.dart';
import '../../../story/presentation/widgets/stories_bar.dart';
import '../widgets/suggested_users_card.dart';
import '../../../create/presentation/pages/creation_camera_page.dart';
import '../../../ads/presentation/providers/ad_provider.dart';
import '../../../ads/presentation/widgets/ad_card_widget.dart';
import '../../../ads/data/models/ad_model.dart';


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

  void _openCamera() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CreationCameraPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    // Watch feed ads
    final ads = ref.watch(feedAdsProvider(5)).value ?? [];

    // Interleave posts, ads and suggested users card
    // Suggestions card is always injected after the 1st post (index 0)
    final List<dynamic> items = [];
    int adIndex = 0;
    bool suggestionsInjected = false;
    for (int i = 0; i < feedState.posts.length; i++) {
      items.add(feedState.posts[i]);
      // Inject after 1st post so suggestions are always visible
      if (i == 0 && !suggestionsInjected) {
        items.add('suggested_users');
        suggestionsInjected = true;
      }
      if ((i + 1) % 4 == 0 && adIndex < ads.length) {
        items.add(ads[adIndex++]);
      }
    }
    // If feed is empty but suggestions loaded, still show them
    if (!suggestionsInjected) {
      items.insert(0, 'suggested_users');
    }

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
        physics: ref.watch(isZoomingProvider)
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
        slivers: [
          // ─── Top Navigation Bar ──────────────────────────
          SliverAppBar(
            pinned: false,
            floating: true,
            snap: true,
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 0,
            toolbarHeight: 56,
            leading: BouncyTap(
              onTap: _openCamera,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(
                  LucideIcons.plus,
                  size: 28,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Instagram',
                style: TextStyle(
                  fontFamily: 'Billabong',
                  fontSize: 32,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            actions: [
              _buildNavIcon(
                iconPath: AppAssets.getIcon('Tab=Like', isDark: isDark, type: 'Default'),
                onTap: () => context.push(AppRoutes.notifications),
                badgeCount: ref.watch(unreadNotificationsCountProvider),
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildNavIcon(
                iconPath: AppAssets.getIcon('Name=Share', isDark: isDark, state: 'Default'),
                onTap: () => context.push(AppRoutes.messages),
                badgeCount: ref.watch(totalUnreadCountProvider),
                isDark: isDark,
              ),
              const SizedBox(width: 16),
            ],
          ),

          // ─── Refresh Control ─────────────────────────────
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await Future.wait([
                ref.read(feedProvider.notifier).refreshFeed(),
                ref.read(storyFeedProvider.notifier).loadStories(),
                ref.refresh(feedAdsProvider(5).future),
              ]);
            },
          ),

          // ─── Stories Section ─────────────────────────────
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
              child: Center(child: AppLoader(size: 60)),
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
                  if (index == items.length) {
                    if (feedState.hasMore) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: AppLoader(size: 40),
                      );
                    }
                    return const SizedBox(height: 50);
                  }

                  final item = items[index];
                  if (item == 'suggested_users') {
                    return SuggestedUsersCard(
                      onSeeAll: () => debugPrint('See all'),
                    );
                  } else if (item is AdModel) {
                    return AdCardWidget(key: ValueKey(item.adId), ad: item);
                  } else {
                    return PostCard(key: ValueKey(item.id), post: item);
                  }
                },
                childCount: items.length + 1,
              ),
            ),
        ],
      ),
    ),
  );

}


  Widget _buildNavIcon({
    required String iconPath,
    required VoidCallback onTap,
    int badgeCount = 0,
    required bool isDark,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(isDark ? Colors.white : Colors.black, BlendMode.srcIn),
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
