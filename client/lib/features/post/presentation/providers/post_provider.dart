// lib/features/post/presentation/providers/post_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/post_service.dart';
import 'feed_provider.dart'; // contains postServiceProvider

class PostState {
  final List<PostModel> posts;
  final List<PostModel> archivedPosts;
  final bool isLoading;
  final String? error;

  const PostState({
    this.posts = const [],
    this.archivedPosts = const [],
    this.isLoading = false,
    this.error,
  });

  List<PostModel> get activePosts =>
    posts.where((p) => !p.isArchived).toList();

  List<PostModel> get pinnedPosts =>
    activePosts.where((p) => p.isPinned).take(3).toList();

  List<PostModel> get regularPosts =>
    activePosts.where((p) => !p.isPinned).toList();

  PostState copyWith({
    List<PostModel>? posts,
    List<PostModel>? archivedPosts,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PostState(
      posts: posts ?? this.posts,
      archivedPosts: archivedPosts ?? this.archivedPosts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PostNotifier extends Notifier<PostState> {
  PostService get _repo => ref.read(postServiceProvider);

  @override
  PostState build() {
    return const PostState();
  }

  // Getters for compatibility
  String? get error => state.error;
  bool get isLoading => state.isLoading;
  List<PostModel> get posts => state.posts;
  List<PostModel> get archivedPosts => state.archivedPosts;
  List<PostModel> get pinnedPosts => state.pinnedPosts;
  List<PostModel> get regularPosts => state.regularPosts;

  void setPosts(List<PostModel> newPosts) {
    state = state.copyWith(posts: List<PostModel>.from(newPosts));
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ── Pin / Unpin ──
  Future<void> togglePin(String postId) async {
    final list = List<PostModel>.from(state.posts);
    final index = list.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = list[index];
    final newPinned = !post.isPinned;

    // Max 3 pinned posts
    if (newPinned && state.pinnedPosts.length >= 3) {
      state = state.copyWith(error: 'You can only pin 3 posts');
      return;
    }

    // Optimistic update
    list[index] = post.copyWith(isPinned: newPinned);
    state = state.copyWith(posts: list);

    try {
      await _repo.updatePost(
        postId: postId,
        data: {'isPinned': newPinned},
      );
    } catch (e) {
      // Rollback
      final rollbackList = List<PostModel>.from(state.posts);
      final rIndex = rollbackList.indexWhere((p) => p.id == postId);
      if (rIndex != -1) {
        rollbackList[rIndex] = post;
      }
      state = state.copyWith(
        posts: rollbackList,
        error: 'Failed to ${newPinned ? "pin" : "unpin"} post',
      );
    }
  }

  // ── Archive / Unarchive ──
  Future<void> toggleArchive(String postId) async {
    final list = List<PostModel>.from(state.posts);
    final index = list.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = list[index];
    final newArchived = !post.isArchived;

    list[index] = post.copyWith(isArchived: newArchived);
    final archivedList = List<PostModel>.from(state.archivedPosts);
    if (newArchived) {
      archivedList.insert(0, list[index]);
    } else {
      archivedList.removeWhere((p) => p.id == postId);
    }

    state = state.copyWith(posts: list, archivedPosts: archivedList);

    try {
      await _repo.updatePost(
        postId: postId,
        data: {'isArchived': newArchived},
      );
    } catch (e) {
      // Rollback
      final rollbackList = List<PostModel>.from(state.posts);
      final rIndex = rollbackList.indexWhere((p) => p.id == postId);
      if (rIndex != -1) {
        rollbackList[rIndex] = post;
      }
      final rollbackArchived = List<PostModel>.from(state.archivedPosts);
      if (newArchived) {
        rollbackArchived.removeWhere((p) => p.id == postId);
      } else {
        rollbackArchived.insert(0, post);
      }
      state = state.copyWith(
        posts: rollbackList,
        archivedPosts: rollbackArchived,
        error: 'Failed to archive post',
      );
    }
  }

  // ── Hide / Show Likes ──
  Future<void> toggleHideLikes(String postId) async {
    final list = List<PostModel>.from(state.posts);
    final index = list.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = list[index];
    final newHide = !post.hideLikesCount;

    list[index] = post.copyWith(hideLikesCount: newHide);
    state = state.copyWith(posts: list);

    try {
      await _repo.updatePost(
        postId: postId,
        data: {'hideLikesCount': newHide},
      );
    } catch (e) {
      // Rollback
      final rollbackList = List<PostModel>.from(state.posts);
      final rIndex = rollbackList.indexWhere((p) => p.id == postId);
      if (rIndex != -1) {
        rollbackList[rIndex] = post;
      }
      state = state.copyWith(
        posts: rollbackList,
        error: 'Failed to update like count visibility',
      );
    }
  }

  // ── Toggle Comments ──
  Future<void> toggleComments(String postId) async {
    final list = List<PostModel>.from(state.posts);
    final index = list.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = list[index];
    final newDisabled = !post.commentsDisabled;

    list[index] = post.copyWith(commentsDisabled: newDisabled);
    state = state.copyWith(posts: list);

    try {
      await _repo.updatePost(
        postId: postId,
        data: {'comments_disabled': newDisabled},
      );
    } catch (e) {
      // Rollback
      final rollbackList = List<PostModel>.from(state.posts);
      final rIndex = rollbackList.indexWhere((p) => p.id == postId);
      if (rIndex != -1) {
        rollbackList[rIndex] = post;
      }
      state = state.copyWith(
        posts: rollbackList,
        error: 'Failed to update commenting',
      );
    }
  }

  // ── Edit Audience ──
  Future<void> updateAudience(String postId, PostAudience audience) async {
    final list = List<PostModel>.from(state.posts);
    final index = list.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = list[index];
    list[index] = post.copyWith(audience: audience);
    state = state.copyWith(posts: list);

    try {
      await _repo.updatePost(
        postId: postId,
        data: {'audience': audience.name},
      );
    } catch (e) {
      // Rollback
      final rollbackList = List<PostModel>.from(state.posts);
      final rIndex = rollbackList.indexWhere((p) => p.id == postId);
      if (rIndex != -1) {
        rollbackList[rIndex] = post;
      }
      state = state.copyWith(
        posts: rollbackList,
        error: 'Failed to update audience',
      );
    }
  }

  // ── Edit Caption/Details ──
  Future<void> editPost({
    required String postId,
    required String caption,
    String? location,
    List<String>? taggedUsers,
  }) async {
    final list = List<PostModel>.from(state.posts);
    final index = list.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = list[index];
    list[index] = post.copyWith(caption: caption, location: location);
    state = state.copyWith(posts: list);

    try {
      await _repo.updatePost(
        postId: postId,
        data: {
          'caption': caption,
          if (location != null) 'location': location,
          if (taggedUsers != null) 'taggedUsers': taggedUsers,
        },
      );
    } catch (e) {
      // Rollback
      final rollbackList = List<PostModel>.from(state.posts);
      final rIndex = rollbackList.indexWhere((p) => p.id == postId);
      if (rIndex != -1) {
        rollbackList[rIndex] = post;
      }
      state = state.copyWith(
        posts: rollbackList,
        error: 'Failed to edit post',
      );
    }
  }

  // ── Delete ──
  Future<void> deletePost(String postId) async {
    final list = List<PostModel>.from(state.posts);
    final index = list.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = list[index];
    list.removeAt(index);
    state = state.copyWith(posts: list);

    try {
      await _repo.deletePost(postId);
    } catch (e) {
      // Rollback
      final rollbackList = List<PostModel>.from(state.posts);
      rollbackList.insert(index, post);
      state = state.copyWith(
        posts: rollbackList,
        error: 'Failed to delete post',
      );
    }
  }
}

// Expose postProvider hook
final postProvider = NotifierProvider<PostNotifier, PostState>(
  PostNotifier.new,
);
