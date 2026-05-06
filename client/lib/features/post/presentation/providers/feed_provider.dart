// lib/features/post/presentation/providers/feed_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/post_service.dart';

// ─── FEED STATE ─────────────────────────────────────────────
class FeedState {
  final List<PostModel> posts;
  final bool isLoading; // Initial load
  final bool isLoadingMore; // Loading next page
  final bool isRefreshing; // Pull to refresh
  final String? errorMessage;
  final bool hasMore; // More pages available
  final int currentPage;
  final bool isEmptyFeed; // No followed users

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 1,
    this.isEmptyFeed = false,
  });

  FeedState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    String? errorMessage,
    bool? hasMore,
    int? currentPage,
    bool? isEmptyFeed,
    bool clearError = false,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      isEmptyFeed: isEmptyFeed ?? this.isEmptyFeed,
    );
  }
}

// ─── FEED NOTIFIER ──────────────────────────────────────────
class FeedNotifier extends Notifier<FeedState> {
  PostService get _postService => ref.read(postServiceProvider);

  @override
  FeedState build() {
    Future.microtask(loadFeed);
    return const FeedState();
  }

  // ─── LOAD INITIAL FEED ──────────────────────────────────
  Future<void> loadFeed() async {
    if (state.isLoading || state.isRefreshing) return;

    state = state.copyWith(
      isLoading: true,
      currentPage: 1,
      clearError: true,
    );

    try {
      final result = await _postService.getFeed(page: 1);
      final posts = result['posts'] as List<PostModel>;
      final pagination = result['pagination'];
      final isEmptyFeed = result['is_empty_feed'] as bool;

      state = state.copyWith(
        posts: posts,
        isLoading: false,
        hasMore: pagination != null
            ? (pagination['hasNextPage'] ?? false)
            : false,
        currentPage: 1,
        isEmptyFeed: isEmptyFeed,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── LOAD MORE (INFINITE SCROLL) ────────────────────────
  Future<void> loadMore() async {
    // Don't load if already loading or no more pages
    if (state.isLoadingMore ||
        !state.hasMore ||
        state.isLoading ||
        state.isRefreshing) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final nextPage = state.currentPage + 1;
      final result = await _postService.getFeed(page: nextPage);
      final newPosts = result['posts'] as List<PostModel>;
      final pagination = result['pagination'];

      state = state.copyWith(
        posts: [...state.posts, ...newPosts], // Append to existing
        isLoadingMore: false,
        hasMore: pagination != null
            ? (pagination['hasNextPage'] ?? false)
            : false,
        currentPage: nextPage,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── REFRESH FEED ────────────────────────────────────────
  Future<void> refreshFeed() async {
    if (state.isRefreshing || state.isLoading) return;

    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final result = await _postService.getFeed(page: 1);
      final posts = result['posts'] as List<PostModel>;
      final pagination = result['pagination'];
      final isEmptyFeed = result['is_empty_feed'] as bool;

      state = state.copyWith(
        posts: posts,
        isRefreshing: false,
        hasMore: pagination != null
            ? (pagination['hasNextPage'] ?? false)
            : false,
        currentPage: 1,
        isEmptyFeed: isEmptyFeed,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── LIKE POST (Optimistic UI) ───────────────────────────
  // Optimistic UI = Update UI immediately, then call API
  // If API fails, revert UI
  Future<void> toggleLike(String postId) async {
    // Find post index
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = state.posts[index];
    final wasLiked = post.isLiked;

    // 1. UPDATE UI IMMEDIATELY (optimistic)
    final updatedPosts = List<PostModel>.from(state.posts);
    updatedPosts[index] = post.copyWith(
      isLiked: !wasLiked,
      likeCount: wasLiked ? post.likeCount - 1 : post.likeCount + 1,
    );
    state = state.copyWith(posts: updatedPosts);

    // 2. CALL API
    try {
      if (wasLiked) {
        await _postService.unlikePost(postId);
      } else {
        await _postService.likePost(postId);
      }
      // Success! UI already updated
    } catch (e) {
      // 3. REVERT if API failed
      final revertedPosts = List<PostModel>.from(state.posts);
      revertedPosts[index] = post; // Restore original
      state = state.copyWith(posts: revertedPosts);
    }
  }

  // ─── SAVE POST (Optimistic UI) ───────────────────────────
  Future<void> toggleSave(String postId) async {
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = state.posts[index];
    final wasSaved = post.isSaved;

    // Update UI immediately
    final updatedPosts = List<PostModel>.from(state.posts);
    updatedPosts[index] = post.copyWith(isSaved: !wasSaved);
    state = state.copyWith(posts: updatedPosts);

    try {
      if (wasSaved) {
        await _postService.unsavePost(postId);
      } else {
        await _postService.savePost(postId);
      }
    } catch (e) {
      // Revert
      final revertedPosts = List<PostModel>.from(state.posts);
      revertedPosts[index] = post;
      state = state.copyWith(posts: revertedPosts);
    }
  }

  Future<void> savePost(String postId) => toggleSave(postId);
  Future<void> unsavePost(String postId) => toggleSave(postId);

  void incrementCommentCount(String postId) {
    state = state.copyWith(
      posts: state.posts.map((post) {
        if (post.id == postId) {
          return post.copyWith(commentCount: post.commentCount + 1);
        }
        return post;
      }).toList(),
    );
  }

  void decrementCommentCount(String postId) {
    state = state.copyWith(
      posts: state.posts.map((post) {
        if (post.id == postId) {
          return post.copyWith(
            commentCount: (post.commentCount - 1).clamp(0, 1 << 31),
          );
        }
        return post;
      }).toList(),
    );
  }

  void addNewPost(PostModel post) {
    state = state.copyWith(
      posts: [post, ...state.posts],
      isEmptyFeed: false,
    );
  }

  // ─── DELETE POST ──────────────────────────────────────────
  Future<void> deletePost(String postId) async {
    try {
      await _postService.deletePost(postId);
      
      // Remove from state
      state = state.copyWith(
        posts: state.posts.where((p) => p.id != postId).toList(),
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final postServiceProvider = Provider<PostService>((ref) {
  return PostService();
});

final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
