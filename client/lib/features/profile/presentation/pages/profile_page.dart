// lib/features/profile/presentation/pages/profile_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/main_shell.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../follow/data/repositories/presentation/providers/follow_provider.dart';
import '../../../follow/data/repositories/presentation/providers/widgets/follow_button.dart';
import '../../../story/presentation/widgets/highlights_bar.dart';
import '../providers/profile_provider.dart';
import '../../data/models/profile_model.dart';
import '../../../messages/data/repositories/message_service.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../post/data/repositories/post_tag_service.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../../core/constants/app_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final String username;

  const ProfilePage({super.key, required this.username});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(profileProvider(widget.username).notifier).loadMorePosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider(widget.username));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen for scroll-to-top signal from MainShell
    ref.listen(profileScrollSignalProvider, (prev, next) {
      if (next > (prev ?? 0) && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuart,
        );
      }
    });

    final followState = profileState.profile != null
        ? ref.watch(followProvider(profileState.profile!.id))
        : const FollowState();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: isDark ? Colors.black : Colors.white,
        border: null,
        automaticallyImplyLeading: false,
        middle: Row(
          children: [
            const SizedBox(width: 16),
            Text(
              widget.username,
              style: TextStyle(
                fontSize: 20, // Modern Instagram size
                fontWeight: FontWeight.w700, // Semi-bold/bold
                fontFamily: 'Instagram-Sans',
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            if (profileState.profile?.isVerified ?? false)
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 0),
                child: VerifiedBadge(size: 15),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showCreateMenu(context),
              child: Icon(
                LucideIcons.plus,
                size: 24,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(width: 16),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.push(AppRoutes.settings),
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  LucideIcons.menu,
                  size: 24,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
      body: profileState.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : profileState.profile == null || followState.hasBlockedMe
              ? const Center(child: Text('Profile not found'))
              : _buildProfile(profileState, followState, isDark),
    );
  }

  Widget _buildProfile(ProfileState state, FollowState followState, bool isDark) {
    final profile = state.profile!;

    return NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(profile, followState),
                _buildBio(profile),
                _buildActionButtons(profile, followState, isDark),
                _buildHighlights(profile, followState),
              ],
            ),
          ),
          if (!followState.isBlocked)
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileTabDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: isDark ? Colors.white : Colors.black,
                  indicatorWeight: 1,
                  labelColor: isDark ? Colors.white : Colors.black,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(icon: Icon(LucideIcons.layout_grid, size: 24, color: isDark ? Colors.white : Colors.black)),
                    Tab(icon: Icon(LucideIcons.clapperboard, size: 24, color: isDark ? Colors.white : Colors.black)),
                    Tab(icon: Icon(LucideIcons.contact, size: 24, color: isDark ? Colors.white : Colors.black)),
                  ],
                ),
                isDark: isDark,
              ),
            ),
        ];
      },
      body: followState.isBlocked
          ? _buildBlockedView(profile, isDark)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPostsGrid(state, profile, followState),
                const Center(child: Text('Reels')),
                _TaggedGrid(username: profile.username),
              ],
            ),
    );
  }

  Widget _buildHeader(ProfileModel profile, FollowState followState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 24, 0),
      child: Row(
        children: [
          _buildAvatar(profile),
          const Spacer(),
          _buildStatItem(followState.isBlocked ? '-' : profile.postCount.toString(), 'post'),
          const SizedBox(width: 24),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: followState.isBlocked ? null : () => context.push('/followers/${profile.id}/${profile.username}'),
            child: _buildStatItem(followState.isBlocked ? '-' : profile.formatCount(profile.followersCount), 'follower'),
          ),
          const SizedBox(width: 24),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: followState.isBlocked ? null : () => context.push('/following/${profile.id}/${profile.username}'),
            child: _buildStatItem(followState.isBlocked ? '-' : profile.formatCount(profile.followingCount), 'following'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ProfileModel profile) {
    return Container(
      width: 79, // Match profile_header_avatar_size_new
      height: 79,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: CircleAvatar(
        backgroundColor: AppColors.border,
        backgroundImage: profile.profilePicUrl != null 
          ? NetworkImage(profile.profilePicUrl!) : null,
        child: profile.profilePicUrl == null
            ? Icon(LucideIcons.user, color: Colors.white, size: 36)
            : null,
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count, 
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.w700,
            fontFamily: 'Instagram-Sans',
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          label, 
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w400,
            fontFamily: 'Instagram-Sans',
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildBio(ProfileModel profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.fullName, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 14,
              fontFamily: 'Instagram-Sans',
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          if (profile.bio != null)
            Text(
              profile.bio!, 
              style: TextStyle(
                fontSize: 14, 
                height: 1.3,
                fontFamily: 'Instagram-Sans',
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          if (profile.website != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => launchUrl(Uri.parse(profile.website!)),
                child: Text(
                  profile.website!.replaceAll('https://', '').replaceAll('http://', ''), 
                  style: const TextStyle(
                    color: Color(0xFF00376B), 
                    fontSize: 14, 
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SF-Pro',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ProfileModel profile, FollowState followState, bool isDark) {
    final btnBg = isDark ? AppColors.darkShimmerBase : AppColors.shimmerBase;
    final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 13);

    if (followState.isBlocked) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _handleUnblock(profile.id),
                child: _CustomProfileButton(
                  text: 'Unblock',
                  backgroundColor: AppColors.primary,
                  textColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: profile.isOwnProfile
          ? Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => context.push(AppRoutes.editProfile),
                    child: _CustomProfileButton(
                      text: 'Edit Profile',
                      backgroundColor: btnBg,
                      textColor: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {},
                    child: _CustomProfileButton(
                      text: 'Share Profile',
                      backgroundColor: btnBg,
                      textColor: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {},
                  child: _CustomProfileButton(
                    icon: LucideIcons.user_plus,
                    backgroundColor: btnBg,
                    textColor: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 5,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _handleFollowToggle(profile.id, followState),
                    child: _CustomProfileButton(
                      text: followState.isFollowing 
                        ? 'Following' 
                        : (followState.isPending ? 'Requested' : 'Follow'),
                      backgroundColor: followState.isFollowing || followState.isPending
                        ? btnBg
                        : const Color(0xFF0095F6),
                      textColor: followState.isFollowing || followState.isPending
                        ? (isDark ? Colors.white : Colors.black)
                        : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _messageUser(profile.id),
                    child: _CustomProfileButton(
                      text: 'Message',
                      backgroundColor: btnBg,
                      textColor: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {},
                  child: _CustomProfileButton(
                    icon: LucideIcons.chevron_down,
                    backgroundColor: btnBg,
                    textColor: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHighlights(ProfileModel profile, FollowState followState) {
    if (followState.isBlocked) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: HighlightsBar(
        username: profile.username,
        isMyProfile: profile.isOwnProfile,
        onAddHighlight: () {},
      ),
    );
  }

  Widget _buildPostsGrid(ProfileState state, ProfileModel profile, FollowState followState) {
    if (followState.isBlocked) return const SizedBox.shrink();
    if (profile.isRestricted == true && !profile.isOwnProfile && !followState.isFollowing) {
      return _buildPrivateView();
    }
    if (state.posts.isEmpty) {
      return const Center(child: Text('No posts yet'));
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: state.posts.length,
      itemBuilder: (context, index) {
        final post = state.posts[index];
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.push('/post/${post.id}'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(imageUrl: post.thumbnailUrl ?? '', fit: BoxFit.cover),
              if (post.isCarousel)
                const Positioned(top: 8, right: 8, child: Icon(LucideIcons.layers, size: 16, color: Colors.white)),
              if (post.isVideo)
                const Positioned(top: 8, right: 8, child: Icon(LucideIcons.play, size: 16, color: Colors.white)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrivateView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey, width: 2),
            ),
            child: const Icon(LucideIcons.lock, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('This account is private', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Follow this account to see their photos and videos.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBlockedView(ProfileModel profile, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('You blocked ${profile.username}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('You won\'t see their posts or stories.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _messageUser(String userId) async {
    try {
      final conv = await MessageService().createOrGetConversation(userId);
      ref.read(inboxProvider.notifier).addConversation(conv);
      if (mounted) context.push('/chat/${conv.id}');
    } catch (e) {
      // Handle error
    }
  }

  void _showCreateMenu(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Create'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.createPost);
            },
            child: const Text('Post'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.createReel);
            },
            child: const Text('Reel'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.createStory);
            },
            child: const Text('Story'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final profile = ref.read(profileProvider(widget.username)).profile;
    if (profile == null) return;

    final followState = ref.read(followProvider(profile.id));
    final isBlocked = followState.isBlocked;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(onPressed: () {}, child: const Text('Report...')),
          CupertinoActionSheetAction(
            isDestructiveAction: !isBlocked,
            onPressed: () {
              Navigator.pop(context);
              if (isBlocked) {
                _handleUnblock(profile.id);
              } else {
                _showBlockConfirmation(context, profile);
              }
            },
            child: Text(isBlocked ? 'Unblock' : 'Block'),
          ),
          CupertinoActionSheetAction(onPressed: () {}, child: const Text('About this account')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
  }

  void _showBlockConfirmation(BuildContext context, ProfileModel profile) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Block ${profile.username}?'),
        content: const Text('They won\'t be able to find your profile, posts or story on Instagram. Instagram won\'t let them know you blocked them.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _handleBlock(profile.id);
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFollowToggle(String userId, FollowState followState) async {
    if (followState.isFollowing) {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Unfollow?'),
          content: const Text('Are you sure you want to unfollow this person?'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Unfollow'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await ref.read(followProvider(userId).notifier).toggleFollow();
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _handleBlock(String userId) async {
    try {
      await ref.read(followProvider(userId).notifier).blockUser();
      if (mounted) {
        AppSnackbar.success(context, 'User blocked');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _handleUnblock(String userId) async {
    try {
      await ref.read(followProvider(userId).notifier).unblockUser();
      if (mounted) {
        AppSnackbar.success(context, 'User unblocked');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }
}

class _CustomProfileButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;

  const _CustomProfileButton({
    this.text,
    this.icon,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32, // Standard IG button height
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: backgroundColor,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: text != null
          ? Text(
              text!, 
              style: TextStyle(
                color: textColor, 
                fontWeight: FontWeight.bold, 
                fontSize: 14,
                fontFamily: 'Instagram-Sans',
              ),
            )
          : Icon(icon, color: textColor, size: 18),
    );
  }
}

class _ProfileTabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;
  _ProfileTabDelegate(this.tabBar, {required this.isDark});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 48,
      color: isDark ? Colors.black : Colors.white,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => 48; // Match tab_bar_height_whiteout
  @override
  double get minExtent => 48;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

// ─────────────────────────────────────────────────────
// TAGGED POSTS GRID
// ─────────────────────────────────────────────────────
class _TaggedGrid extends ConsumerWidget {
  final String username;
  const _TaggedGrid({required this.username});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<dynamic>>(
      future: ref.read(postTagServiceProvider).getTaggedPosts(
        username: username,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load tagged posts',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey,
                fontSize: 14,
              ),
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.user_round_plus,
                      size:  48,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  Text(
                    'Photos of you',
                    style: IgText.h2.copyWith(color: isDark ? Colors.white : Colors.black),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'When people tag you in photos,\nthey\'ll appear here.',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding:         EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   3,
            crossAxisSpacing: 1,
            mainAxisSpacing:  1,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index] as Map<String, dynamic>;
            final cover = post['media_url']?.toString() ?? post['coverUrl']?.toString();
            final postId = post['id']?.toString() ?? '';

            return CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.push('/post/$postId'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cover != null
                      ? CachedNetworkImage(
                          imageUrl:   cover,
                          fit:        BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: isDark ? Colors.grey[900] : Colors.grey[200],
                          ),
                        )
                      : Container(color: isDark ? Colors.grey[900] : Colors.grey[200]),

                  // Tag icon overlay
                  const Positioned(
                    top:   8,
                    right: 8,
                    child: Icon(
                      LucideIcons.contact,
                      color: Colors.white,
                      size:  18,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black45),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

