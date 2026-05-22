// lib/features/follow/presentation/pages/followers_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../../../core/router/navigation_extensions.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../../../shared/widgets/user_story_avatar.dart';
import '../../follow_service.dart';
import '../providers/widgets/follow_button.dart';

class FollowersPage extends ConsumerStatefulWidget {
  final String userId;
  final String username;

  const FollowersPage({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  ConsumerState<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends ConsumerState<FollowersPage> {
  final FollowService _service = FollowService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _searchQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadFollowers({bool reset = false}) async {
    if (reset) {
      setState(() {
        _users = [];
        _currentPage = 1;
        _hasMore = true;
        _isLoading = true;
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final result = await _service.getFollowers(
        userId: widget.userId,
        page: 1,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      final users = List<Map<String, dynamic>>.from(result['users'] as List);
      final pagination = result['pagination'];

      setState(() {
        _users = users;
        _isLoading = false;
        _hasMore = pagination?['hasNextPage'] ?? false;
        _currentPage = 1;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _service.getFollowers(
        userId: widget.userId,
        page: _currentPage + 1,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      final newUsers = List<Map<String, dynamic>>.from(result['users'] as List);
      final pagination = result['pagination'];

      setState(() {
        _users.addAll(newUsers);
        _isLoadingMore = false;
        _hasMore = pagination?['hasNextPage'] ?? false;
        _currentPage++;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == value) {
        _loadFollowers(reset: true);
      }
    });
  }

  bool get _isOwnProfile {
    final currentUser = ref.read(currentUserProvider);
    return currentUser?.id == widget.userId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          '@${widget.username}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),
          const Divider(height: 1, color: AppColors.border),

          // User list
          Expanded(
            child: _isLoading
                ? const _UserListSkeleton()
                : _error != null
                ? _ErrorWidget(
                    message: _error!,
                    onRetry: () => _loadFollowers(),
                  )
                : _users.isEmpty
                ? _EmptyWidget(
                    message: _searchQuery.isNotEmpty
                        ? 'No results for "$_searchQuery"'
                        : 'No followers yet',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _users.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _users.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }

                      final user = _users[index];
                      return _UserListItem(
                        user: user,
                        showRemoveOption: _isOwnProfile,
                        onRemove: () async {
                          await _service.removeFollower(user['id']);
                          setState(() => _users.remove(user));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }
}

// ─── FOLLOWING PAGE ──────────────────────────────────────────
class FollowingPage extends ConsumerStatefulWidget {
  final String userId;
  final String username;

  const FollowingPage({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  ConsumerState<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends ConsumerState<FollowingPage> {
  final FollowService _service = FollowService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _searchQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadFollowing({bool reset = false}) async {
    setState(() => _isLoading = true);

    try {
      final result = await _service.getFollowing(
        userId: widget.userId,
        page: 1,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      setState(() {
        _users = List<Map<String, dynamic>>.from(result['users'] as List);
        _isLoading = false;
        _hasMore = result['pagination']?['hasNextPage'] ?? false;
        _currentPage = 1;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _service.getFollowing(
        userId: widget.userId,
        page: _currentPage + 1,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      setState(() {
        _users.addAll(List<Map<String, dynamic>>.from(result['users'] as List));
        _isLoadingMore = false;
        _hasMore = result['pagination']?['hasNextPage'] ?? false;
        _currentPage++;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == value) _loadFollowing(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          '@${widget.username}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _isLoading
                ? const _UserListSkeleton()
                : _error != null
                ? _ErrorWidget(
                    message: _error!,
                    onRetry: () => _loadFollowing(),
                  )
                : _users.isEmpty
                ? _EmptyWidget(
                    message: _searchQuery.isNotEmpty
                        ? 'No results for "$_searchQuery"'
                        : 'Not following anyone yet',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _users.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _users.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }

                      return _UserListItem(
                        user: _users[index],
                        showRemoveOption: false,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }
}

// ─── SHARED USER LIST ITEM ───────────────────────────────────
class _UserListItem extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool showRemoveOption;
  final VoidCallback? onRemove;

  const _UserListItem({
    required this.user,
    required this.showRemoveOption,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final username = user['username'] as String? ?? '';
    final fullName = user['full_name'] as String? ?? '';
    final profilePicUrl = user['profile_pic_url'] as String?;
    final isVerified = user['is_verified'] as bool? ?? false;
    final userId = user['id'] as String? ?? '';

    return ListTile(
      onTap: () => context.pushIfNotCurrent('/profile/$username'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: UserStoryAvatar(
        userId: userId,
        profilePicUrl: profilePicUrl,
        username: username,
        size: 44,
        showPresence: false,
        isClickable: true,
      ),
      title: Row(
        children: [
          Text(
            username,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          if (isVerified) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, size: 14, color: AppColors.primary),
          ],
        ],
      ),
      subtitle: fullName.isNotEmpty
          ? Text(
              fullName,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            )
          : null,
      trailing: showRemoveOption
          ? _RemoveButton(onRemove: onRemove)
          : FollowButton(targetUserId: userId, compact: true),
    );
  }
}

class _RemoveButton extends StatefulWidget {
  final VoidCallback? onRemove;
  const _RemoveButton({this.onRemove});

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _removed = false;

  @override
  Widget build(BuildContext context) {
    if (_removed) return const SizedBox.shrink();

    return OutlinedButton(
      onPressed: () {
        setState(() => _removed = true);
        widget.onRemove?.call();
      },
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'Remove',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── SKELETON ────────────────────────────────────────────────
class _UserListSkeleton extends StatelessWidget {
  const _UserListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.border,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, width: 120, color: AppColors.border),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 80,
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            Container(
              width: 80,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SHARED EMPTY + ERROR ────────────────────────────────────
class _EmptyWidget extends StatelessWidget {
  final String message;
  const _EmptyWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 60, color: AppColors.border),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorWidget({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
