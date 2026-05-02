// lib/features/profile/presentation/pages/profile_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../follow/data/repositories/presentation/providers/widgets/follow_button.dart';
import '../providers/profile_provider.dart';
import '../../data/models/profile_model.dart';
import '../../../messages/data/repositories/message_service.dart';
import '../../../messages/presentation/providers/message_provider.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.white,

      // ─── APP BAR ────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
              )
            : null,
        title: Text(
          widget.username,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          if (profileState.profile?.isOwnProfile == true) ...[
            IconButton(
              onPressed: () => _showProfileMenu(context),
              icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            ),
          ] else ...[
            IconButton(
              onPressed: () => _showMoreOptions(context),
              icon: const Icon(Icons.more_horiz, color: AppColors.textPrimary),
            ),
          ],
        ],
      ),

      // ─── BODY ───────────────────────────────────────────
      body: profileState.isLoading
          ? const _ProfileSkeleton()
          : profileState.errorMessage != null && profileState.profile == null
          ? _ErrorState(
              message: profileState.errorMessage!,
              onRetry: () =>
                  ref.read(profileProvider(widget.username).notifier).refresh(),
            )
          : _buildProfile(profileState, currentUser),
    );
  }

  // ─── PROFILE CONTENT ────────────────────────────────────────
  Widget _buildProfile(ProfileState profileState, dynamic currentUser) {
    final profile = profileState.profile!;

    return NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── HEADER ─────────────────────────────
                _buildHeader(profile),

                // ─── BIO SECTION ─────────────────────────
                _buildBioSection(profile),

                // ─── ACTION BUTTONS ──────────────────────
                _buildActionButtons(profile),

                // ─── HIGHLIGHTS ──────────────────────────
                _buildHighlights(),

                // Divider
                const Divider(height: 1, color: AppColors.border),
              ],
            ),
          ),

          // ─── TAB BAR ──────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.textPrimary,
                indicatorWeight: 1,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on, size: 22)),
                  Tab(icon: Icon(Icons.person_pin_outlined, size: 22)),
                ],
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          // Posts tab
          _buildPostsGrid(profileState, profile),
          // Tagged tab (placeholder)
          const _TaggedPlaceholder(),
        ],
      ),
    );
  }

  // ─── HEADER (avatar + stats) ─────────────────────────────────
  Widget _buildHeader(ProfileModel profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── AVATAR ──────────────────────────────────
          _buildAvatar(profile),

          const SizedBox(width: 24),

          // ─── STATS ───────────────────────────────────
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(
                  count: profile.formatCount(profile.postCount),
                  label: 'Posts',
                  onTap: null,
                ),
                _StatItem(
                  count: profile.formatCount(profile.followersCount),
                  label: 'Followers',
                  onTap: () => context.push(
                    '/followers/${profile.id}?username=${profile.username}',
                  ),
                ),
                _StatItem(
                  count: profile.formatCount(profile.followingCount),
                  label: 'Following',
                  onTap: () => context.push(
                    '/following/${profile.id}?username=${profile.username}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── AVATAR ──────────────────────────────────────────────────
  Widget _buildAvatar(ProfileModel profile) {
    return GestureDetector(
      onTap: profile.isOwnProfile
          ? () => context.push(AppRoutes.editProfile)
          : null,
      child: Stack(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: ClipOval(
              child: profile.profilePicUrl != null
                  ? CachedNetworkImage(
                      imageUrl: profile.profilePicUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.border),
                      errorWidget: (_, __, ___) =>
                          _defaultAvatar(profile.username),
                    )
                  : _defaultAvatar(profile.username),
            ),
          ),

          // Edit icon overlay (own profile)
          if (profile.isOwnProfile)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 14),
              ),
            ),
        ],
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
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─── BIO SECTION ─────────────────────────────────────────────
  Widget _buildBioSection(ProfileModel profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full name
          Row(
            children: [
              Text(
                profile.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 16, color: AppColors.primary),
              ],
            ],
          ),

          // Bio
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              profile.bio!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ],

          // Website link
          if (profile.website != null && profile.website!.isNotEmpty) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final url = profile.website!.startsWith('http')
                    ? profile.website!
                    : 'https://${profile.website}';
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: Text(
                profile.website!,
                style: const TextStyle(
                  color: AppColors.textLink,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],

          // "Followed by" text
          if (profile.isFollowedBy == true && !profile.isOwnProfile) ...[
            const SizedBox(height: 6),
            const Text(
              'Follows you',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  // ─── ACTION BUTTONS ──────────────────────────────────────────
  Widget _buildActionButtons(ProfileModel profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: profile.isOwnProfile
          ? _buildOwnProfileButtons(profile)
          : _buildOtherProfileButtons(profile),
    );
  }

  Widget _buildOwnProfileButtons(ProfileModel profile) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.push(AppRoutes.editProfile),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text(
              'Edit Profile',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () =>
              AppSnackbar.info(context, 'Share profile coming soon!'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          ),
          child: const Icon(
            Icons.person_add_outlined,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildOtherProfileButtons(ProfileModel profile) {
    return Row(
      children: [
        // Follow Button
        Expanded(flex: 2, child: FollowButton(targetUserId: profile.id)),

        const SizedBox(width: 8),

        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: () async {
              // Create or get DM conversation
              try {
                final service = MessageService();
                final conv = await service.createOrGetConversation(profile.id);
                // Add to inbox
                ref.read(inboxProvider.notifier).addConversation(conv);
                if (context.mounted) {
                  context.push('/chat/${conv.id}');
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackbar.error(context, 'Error: $e');
                }
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text('Message'),
          ),
        ),

        const SizedBox(width: 8),

        // More options chevron
        OutlinedButton(
          onPressed: () => _showMoreOptions(context),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          ),
          child: const Icon(
            Icons.expand_more,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ─── HIGHLIGHTS ──────────────────────────────────────────────
  Widget _buildHighlights() {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // New highlight (own profile only)
          if (ref
                  .read(profileProvider(widget.username))
                  .profile
                  ?.isOwnProfile ==
              true)
            _HighlightItem(
              label: 'New',
              isNew: true,
              onTap: () =>
                  AppSnackbar.info(context, 'Highlights coming soon!'),
            ),

          // Placeholder highlights
          _HighlightItem(label: 'Travel', isNew: false),
          _HighlightItem(label: 'Food', isNew: false),
          _HighlightItem(label: 'Life', isNew: false),
        ],
      ),
    );
  }

  // ─── POSTS GRID ──────────────────────────────────────────────
  Widget _buildPostsGrid(ProfileState profileState, ProfileModel profile) {
    // Private and not following
    if (profile.isRestricted == true) {
      return const _PrivateAccountState();
    }

    // Loading
    if (profileState.isLoadingPosts && profileState.posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // Empty
    if (profileState.posts.isEmpty) {
      return const _EmptyPostsState();
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount:
          profileState.posts.length + (profileState.isLoadingMore ? 3 : 0),
      itemBuilder: (context, index) {
        // Loading placeholders
        if (index >= profileState.posts.length) {
          return Container(color: AppColors.border);
        }

        final post = profileState.posts[index];
        return _PostGridItem(post: post);
      },
    );
  }

  // ─── MENUS ───────────────────────────────────────────────────
  void _showProfileMenu(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16),
      ),
    ),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),

        // ⭐ Settings - navigates to settings page
        _MenuTile(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: () {
            Navigator.pop(ctx);
            context.push('/settings'); // ⭐ Navigate to settings
          },
        ),

        _MenuTile(
          icon: Icons.archive_outlined,
          label: 'Archive',
          onTap: () => Navigator.pop(ctx),
        ),

        _MenuTile(
          icon: Icons.bar_chart_outlined,
          label: 'Insights',
          onTap: () => Navigator.pop(ctx),
        ),

        _MenuTile(
          icon: Icons.qr_code,
          label: 'QR Code',
          onTap: () => Navigator.pop(ctx),
        ),

        const SizedBox(height: 8),
      ],
    ),
  );
}

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.block,
            label: 'Block',
            color: AppColors.secondary,
            onTap: () => Navigator.pop(ctx),
          ),
          _MenuTile(
            icon: Icons.report_outlined,
            label: 'Report',
            color: AppColors.secondary,
            onTap: () => Navigator.pop(ctx),
          ),
          _MenuTile(
            icon: Icons.link,
            label: 'Copy link',
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── STAT ITEM ───────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String count;
  final String label;
  final VoidCallback? onTap;

  const _StatItem({required this.count, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ─── HIGHLIGHT ITEM ──────────────────────────────────────────
class _HighlightItem extends StatelessWidget {
  final String label;
  final bool isNew;
  final VoidCallback? onTap;

  const _HighlightItem({required this.label, required this.isNew, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isNew ? AppColors.border : AppColors.textSecondary,
                  width: 1,
                ),
                color: isNew
                    ? AppColors.background
                    : AppColors.border.withOpacity(0.3),
              ),
              child: isNew
                  ? const Icon(
                      Icons.add,
                      color: AppColors.textPrimary,
                      size: 26,
                    )
                  : const Icon(
                      Icons.play_circle_outline,
                      color: AppColors.textSecondary,
                      size: 26,
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── POST GRID ITEM ──────────────────────────────────────────
class _PostGridItem extends StatelessWidget {
  final ProfilePostModel post;

  const _PostGridItem({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          post.thumbnailUrl != null
              ? CachedNetworkImage(
                  imageUrl: post.thumbnailUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.border),
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

          // Multiple images indicator
          if (post.isCarousel)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(
                Icons.collections,
                color: Colors.white,
                size: 18,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),

          // Video indicator
          if (post.isVideo)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 18,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── TAB BAR DELEGATE ────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.white, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

// ─── MENU TILE ───────────────────────────────────────────────
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ─── SKELETON LOADING ────────────────────────────────────────
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.border,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    3,
                    (i) => Column(
                      children: [
                        Container(
                          width: 40,
                          height: 16,
                          color: AppColors.border,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 60,
                          height: 12,
                          color: AppColors.border.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(width: 120, height: 14, color: AppColors.border),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 12,
            color: AppColors.border.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}

// ─── PRIVATE ACCOUNT STATE ───────────────────────────────────
class _PrivateAccountState extends StatelessWidget {
  const _PrivateAccountState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(
              Icons.lock_outline,
              size: 60,
              color: AppColors.textPrimary,
            ),
            const SizedBox(height: 16),
            const Text(
              'This Account is Private',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Follow this account to see their photos and videos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EMPTY POSTS STATE ───────────────────────────────────────
class _EmptyPostsState extends StatelessWidget {
  const _EmptyPostsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 60, color: AppColors.border),
            SizedBox(height: 16),
            Text(
              'No Posts Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TAGGED PLACEHOLDER ──────────────────────────────────────
class _TaggedPlaceholder extends StatelessWidget {
  const _TaggedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_pin_outlined, size: 60, color: AppColors.border),
          SizedBox(height: 16),
          Text(
            'Photos of you',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Coming soon!',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── ERROR STATE ─────────────────────────────────────────────
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
              Icons.error_outline,
              size: 60,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
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
