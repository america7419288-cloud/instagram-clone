// lib/features/search/presentation/pages/hashtag_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/navigation_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/search_service.dart';

class HashtagPage extends ConsumerStatefulWidget {
  final String tag;

  const HashtagPage({super.key, required this.tag});

  @override
  ConsumerState<HashtagPage> createState() => _HashtagPageState();
}

class _HashtagPageState extends ConsumerState<HashtagPage> {
  final SearchService _service = SearchService();
  List<Map<String, dynamic>> _posts = [];
  int _postCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _posts = [];
        _isLoading = true;
      });
    }

    try {
      final result = await _service.getHashtagPosts(
        tag: widget.tag,
        page: _page,
      );

      setState(() {
        _posts = [
          ..._posts,
          ...List<Map<String, dynamic>>.from(result['posts'] as List),
        ];
        _postCount = result['post_count'] as int? ?? 0;
        _isLoading = false;
        _hasMore = result['has_next'] as bool? ?? false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
      _page++;
    });

    try {
      final result = await _service.getHashtagPosts(
        tag: widget.tag,
        page: _page,
      );

      setState(() {
        _posts.addAll(List<Map<String, dynamic>>.from(result['posts'] as List));
        _isLoadingMore = false;
        _hasMore = result['has_next'] as bool? ?? false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _page--;
      });
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          '#${widget.tag}',
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 300) {
                  _loadMore();
                }
                return false;
              },
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(child: _buildHeader()),

                  // Grid
                  SliverPadding(
                    padding: const EdgeInsets.all(2),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                            childAspectRatio: 1,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index >= _posts.length) return null;
                        final post = _posts[index];
                        final postId = post['id'] as String? ?? '';
                        final thumbnailUrl = post['thumbnail_url'] as String?;

                        return GestureDetector(
                          onTap: () =>
                              context.pushIfNotCurrent('/post/$postId'),
                          child: thumbnailUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      Container(color: AppColors.border),
                                )
                              : Container(color: AppColors.border),
                        );
                      }, childCount: _posts.length),
                    ),
                  ),

                  // Load more indicator
                  if (_isLoadingMore)
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

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Hashtag icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: const Center(
              child: Text(
                '#',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Hashtag name
          Text(
            '#${widget.tag}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),

          // Post count
          Text(
            '${_formatCount(_postCount)} posts',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),

          // Posts tab
          const Divider(height: 1, color: AppColors.border),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grid_on, size: 20, color: AppColors.textPrimary),
                SizedBox(width: 8),
                Text(
                  'Posts',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }
}
