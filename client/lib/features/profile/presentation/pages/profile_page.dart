// lib/features/profile/presentation/pages/profile_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/main_shell.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../follow/data/repositories/presentation/providers/follow_provider.dart';
import '../../../follow/data/repositories/presentation/providers/widgets/follow_button.dart';
import '../../../story/presentation/widgets/highlights_bar.dart';
import '../providers/profile_provider.dart';
import '../../data/models/profile_model.dart';
import '../../../messages/data/repositories/message_service.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../../core/theme/app_theme.dart';

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
        leading: Navigator.canPop(context)
            ? BouncyTap(
                onTap: () => context.pop(),
                child: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(CupertinoIcons.chevron_back, size: 28),
                ),
              )
            : null,
        middle: Text(
          widget.username,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'SF-Pro'),
        ),
        trailing: profileState.profile?.isOwnProfile == true
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BouncyTap(
                    onTap: () => _showCreateMenu(context),
                    child: const Icon(CupertinoIcons.plus_app, size: 24),
                  ),
                  const SizedBox(width: 12),
                  BouncyTap(
                    onTap: () => context.push(AppRoutes.settings),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(CupertinoIcons.line_horizontal_3, size: 24),
                    ),
                  ),
                ],
              )
            : BouncyTap(
                onTap: () => _showMoreOptions(context),
                child: const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(CupertinoIcons.ellipsis, size: 22),
                ),
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
                  tabs: const [
                    Tab(icon: Icon(CupertinoIcons.square_on_square, size: 22)),
                    Tab(icon: Icon(CupertinoIcons.play_circle, size: 22)),
                    Tab(icon: Icon(CupertinoIcons.person_crop_circle, size: 22)),
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
                const Center(child: Text('Tagged')),
              ],
            ),
    );
  }

  Widget _buildHeader(ProfileModel profile, FollowState followState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildAvatar(profile),
          _buildStatItem(followState.isBlocked ? '-' : profile.postCount.toString(), 'Posts'),
          BouncyTap(
            onTap: followState.isBlocked ? null : () => context.push('/followers/${profile.id}/${profile.username}'),
            child: _buildStatItem(followState.isBlocked ? '-' : profile.formatCount(profile.followersCount), 'Followers'),
          ),
          BouncyTap(
            onTap: followState.isBlocked ? null : () => context.push('/following/${profile.id}/${profile.username}'),
            child: _buildStatItem(followState.isBlocked ? '-' : profile.formatCount(profile.followingCount), 'Following'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ProfileModel profile) {
    return Container(
      width: 77,
      height: 77,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1),
      ),
      child: CircleAvatar(
        radius: 35,
        backgroundColor: AppColors.border,
        backgroundImage: profile.profilePicUrl != null ? NetworkImage(profile.profilePicUrl!) : null,
        child: profile.profilePicUrl == null
            ? const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 35)
            : null,
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400)),
      ],
    );
  }

  Widget _buildBio(ProfileModel profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(profile.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          if (profile.bio != null)
            Text(profile.bio!, style: const TextStyle(fontSize: 13, height: 1.2)),
          if (profile.website != null)
            BouncyTap(
              onTap: () => launchUrl(Uri.parse(profile.website!)),
              child: Text(profile.website!, style: const TextStyle(color: AppColors.link, fontSize: 13, fontWeight: FontWeight.w500)),
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
              child: BouncyTap(
                onTap: () => _handleUnblock(profile.id),
                child: _CupertinoButton(
                  onPressed: () {},
                  text: 'Unblock',
                  backgroundColor: AppColors.primary,
                  textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
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
                  child: BouncyTap(
                    onTap: () => context.push(AppRoutes.editProfile),
                    child: _CupertinoButton(
                      onPressed: () {}, // Handled by BouncyTap
                      text: 'Edit Profile',
                      backgroundColor: btnBg,
                      textStyle: textStyle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BouncyTap(
                    onTap: () {},
                    child: _CupertinoButton(
                      onPressed: () {},
                      text: 'Share Profile',
                      backgroundColor: btnBg,
                      textStyle: textStyle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                BouncyTap(
                  onTap: () {},
                  child: _CupertinoButton(
                    onPressed: () {},
                    icon: CupertinoIcons.person_add,
                    backgroundColor: btnBg,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: FollowButton(targetUserId: profile.id)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: BouncyTap(
                    onTap: () => _messageUser(profile.id),
                    child: _CupertinoButton(
                      onPressed: () {},
                      text: 'Message',
                      backgroundColor: btnBg,
                      textStyle: textStyle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                BouncyTap(
                  onTap: () {},
                  child: _CupertinoButton(
                    onPressed: () {},
                    icon: CupertinoIcons.person_add,
                    backgroundColor: btnBg,
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
        return BouncyTap(
          onTap: () => context.push('/post/${post.id}'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(imageUrl: post.thumbnailUrl ?? '', fit: BoxFit.cover),
              if (post.isCarousel)
                const Positioned(top: 8, right: 8, child: Icon(CupertinoIcons.layers_fill, size: 16, color: Colors.white)),
              if (post.isVideo)
                const Positioned(top: 8, right: 8, child: Icon(CupertinoIcons.play_fill, size: 16, color: Colors.white)),
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
            child: const Icon(CupertinoIcons.lock_fill, size: 40),
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

class _CupertinoButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String? text;
  final IconData? icon;
  final Color backgroundColor;
  final TextStyle? textStyle;

  const _CupertinoButton({
    required this.onPressed,
    this.text,
    this.icon,
    required this.backgroundColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: backgroundColor,
      ),
      alignment: Alignment.center,
      child: text != null
          ? Text(text!, style: textStyle)
          : Icon(icon, color: textStyle?.color ?? Colors.black, size: 18),
    );
  }
}

class _ProfileTabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;
  _ProfileTabDelegate(this.tabBar, {required this.isDark});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: isDark ? Colors.black : Colors.white, child: tabBar);
  }

  @override
  double get maxExtent => 44;
  @override
  double get minExtent => 44;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

