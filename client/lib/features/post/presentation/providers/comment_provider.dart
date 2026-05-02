// lib/features/post/presentation/providers/comment_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/comment_model.dart';
import '../../data/repositories/comment_service.dart';
import 'feed_provider.dart';

// ─── COMMENT STATE ──────────────────────────────────────────
class CommentState {
  final List<CommentModel> comments;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSubmitting; // Adding/replying
  final String? errorMessage;
  final bool hasMore;
  final int currentPage;
  // Reply state
  final CommentModel? replyingTo;
  // Replies for each comment
  final Map<String, List<CommentModel>> replies;
  final Map<String, bool> loadingReplies;

  const CommentState({
    this.comments = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 1,
    this.replyingTo,
    this.replies = const {},
    this.loadingReplies = const {},
  });

  CommentState copyWith({
    List<CommentModel>? comments,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSubmitting,
    String? errorMessage,
    bool? hasMore,
    int? currentPage,
    CommentModel? replyingTo,
    bool clearReplyingTo = false,
    Map<String, List<CommentModel>>? replies,
    Map<String, bool>? loadingReplies,
  }) {
    return CommentState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      replyingTo: clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
      replies: replies ?? this.replies,
      loadingReplies: loadingReplies ?? this.loadingReplies,
    );
  }
}

// ─── COMMENT NOTIFIER ───────────────────────────────────────
class CommentNotifier extends StateNotifier<CommentState> {
  final CommentService _commentService;
  final String postId;
  final Ref _ref;

  CommentNotifier(this._commentService, this.postId, this._ref)
    : super(const CommentState()) {
    loadComments();
  }

  // ─── LOAD COMMENTS ──────────────────────────────────────
  Future<void> loadComments() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _commentService.getComments(postId: postId, page: 1);

      final comments = result['comments'] as List<CommentModel>;
      final pagination = result['pagination'];

      state = state.copyWith(
        comments: comments,
        isLoading: false,
        hasMore: pagination?['hasNextPage'] ?? false,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── LOAD MORE COMMENTS ──────────────────────────────────
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final result = await _commentService.getComments(
        postId: postId,
        page: nextPage,
      );

      final newComments = result['comments'] as List<CommentModel>;
      final pagination = result['pagination'];

      state = state.copyWith(
        comments: [...state.comments, ...newComments],
        isLoadingMore: false,
        hasMore: pagination?['hasNextPage'] ?? false,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // ─── ADD COMMENT ─────────────────────────────────────────
  Future<bool> addComment(String content) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final newComment = await _commentService.addComment(
        postId: postId,
        content: content,
      );

      // Add to top of list (newest first position)
      // But after pinned comments
      final updatedComments = List<CommentModel>.from(state.comments);
      final firstNonPinnedIndex = updatedComments.indexWhere(
        (c) => !c.isPinned,
      );

      if (firstNonPinnedIndex == -1) {
        updatedComments.add(newComment);
      } else {
        updatedComments.insert(firstNonPinnedIndex, newComment);
      }

      state = state.copyWith(
        comments: updatedComments,
        isSubmitting: false,
        clearReplyingTo: true,
      );
      _ref.read(feedProvider.notifier).incrementCommentCount(postId);

      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // ─── REPLY TO COMMENT ────────────────────────────────────
  Future<bool> replyToComment(String commentId, String content) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final reply = await _commentService.replyToComment(
        commentId: commentId,
        content: content,
      );

      // Update reply count on parent comment
      final updatedComments = state.comments.map((c) {
        if (c.id == commentId) {
          return c.copyWith(
            replyCount: c.replyCount + 1,
            repliesExpanded: true,
          );
        }
        return c;
      }).toList();

      // Add reply to replies map
      final updatedReplies = Map<String, List<CommentModel>>.from(
        state.replies,
      );
      final existingReplies = updatedReplies[commentId] ?? [];
      updatedReplies[commentId] = [...existingReplies, reply];

      state = state.copyWith(
        comments: updatedComments,
        replies: updatedReplies,
        isSubmitting: false,
        clearReplyingTo: true,
      );
      _ref.read(feedProvider.notifier).incrementCommentCount(postId);

      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // ─── LOAD REPLIES FOR COMMENT ────────────────────────────
  Future<void> loadReplies(String commentId) async {
    // Toggle: if already expanded, collapse
    final existingReplies = state.replies[commentId];
    if (existingReplies != null) {
      final updatedComments = state.comments.map((c) {
        if (c.id == commentId) {
          return c.copyWith(repliesExpanded: !c.repliesExpanded);
        }
        return c;
      }).toList();
      state = state.copyWith(comments: updatedComments);
      return;
    }

    // Set loading
    final updatedLoading = Map<String, bool>.from(state.loadingReplies);
    updatedLoading[commentId] = true;
    state = state.copyWith(loadingReplies: updatedLoading);

    try {
      final replies = await _commentService.getReplies(commentId: commentId);

      final updatedReplies = Map<String, List<CommentModel>>.from(
        state.replies,
      );
      updatedReplies[commentId] = replies;

      final updatedLoadingDone = Map<String, bool>.from(state.loadingReplies);
      updatedLoadingDone[commentId] = false;

      // Mark comment as expanded
      final updatedComments = state.comments.map((c) {
        if (c.id == commentId) {
          return c.copyWith(repliesExpanded: true);
        }
        return c;
      }).toList();

      state = state.copyWith(
        comments: updatedComments,
        replies: updatedReplies,
        loadingReplies: updatedLoadingDone,
      );
    } catch (e) {
      final updatedLoading = Map<String, bool>.from(state.loadingReplies);
      updatedLoading[commentId] = false;
      state = state.copyWith(loadingReplies: updatedLoading);
    }
  }

  // ─── TOGGLE LIKE COMMENT (Optimistic UI) ─────────────────
  Future<void> toggleCommentLike(String commentId) async {
    // Find comment (could be top-level or in replies)
    final index = state.comments.indexWhere((c) => c.id == commentId);

    if (index != -1) {
      // Top-level comment
      final comment = state.comments[index];
      final wasLiked = comment.isLiked;

      // Update immediately
      final updatedComments = List<CommentModel>.from(state.comments);
      updatedComments[index] = comment.copyWith(
        isLiked: !wasLiked,
        likeCount: wasLiked ? comment.likeCount - 1 : comment.likeCount + 1,
      );
      state = state.copyWith(comments: updatedComments);

      try {
        if (wasLiked) {
          await _commentService.unlikeComment(commentId);
        } else {
          await _commentService.likeComment(commentId);
        }
      } catch (e) {
        // Revert on failure
        final revertedComments = List<CommentModel>.from(state.comments);
        revertedComments[index] = comment;
        state = state.copyWith(comments: revertedComments);
      }
    } else {
      // Search in replies
      final updatedReplies = Map<String, List<CommentModel>>.from(
        state.replies,
      );

      for (final entry in updatedReplies.entries) {
        final replyIndex = entry.value.indexWhere((r) => r.id == commentId);

        if (replyIndex != -1) {
          final reply = entry.value[replyIndex];
          final wasLiked = reply.isLiked;

          // Update optimistically
          final updatedList = List<CommentModel>.from(entry.value);
          updatedList[replyIndex] = reply.copyWith(
            isLiked: !wasLiked,
            likeCount: wasLiked ? reply.likeCount - 1 : reply.likeCount + 1,
          );
          updatedReplies[entry.key] = updatedList;
          state = state.copyWith(replies: updatedReplies);

          try {
            if (wasLiked) {
              await _commentService.unlikeComment(commentId);
            } else {
              await _commentService.likeComment(commentId);
            }
          } catch (e) {
            // Revert
            final revertList = List<CommentModel>.from(entry.value);
            revertList[replyIndex] = reply;
            updatedReplies[entry.key] = revertList;
            state = state.copyWith(replies: updatedReplies);
          }
          break;
        }
      }
    }
  }

  // ─── DELETE COMMENT ──────────────────────────────────────
  Future<void> deleteComment(String commentId) async {
    final topLevelIndex = state.comments.indexWhere((c) => c.id == commentId);
    if (topLevelIndex != -1) {
      final removedComment = state.comments[topLevelIndex];
      final removedReplies = state.replies[commentId];
      final updatedComments = state.comments
          .where((c) => c.id != commentId)
          .toList();
      final updatedReplies = Map<String, List<CommentModel>>.from(state.replies);
      updatedReplies.remove(commentId);

      state = state.copyWith(
        comments: updatedComments,
        replies: updatedReplies,
        errorMessage: null,
      );

      try {
        await _commentService.deleteComment(commentId);
        _ref.read(feedProvider.notifier).decrementCommentCount(postId);
      } catch (e) {
        final restoredComments = List<CommentModel>.from(state.comments);
        restoredComments.insert(topLevelIndex, removedComment);
        final restoredReplies = Map<String, List<CommentModel>>.from(
          state.replies,
        );
        if (removedReplies != null) {
          restoredReplies[commentId] = removedReplies;
        }

        state = state.copyWith(
          comments: restoredComments,
          replies: restoredReplies,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      }
      return;
    }

    String? parentCommentId;
    CommentModel? removedReply;
    int removedReplyIndex = -1;
    final updatedReplies = Map<String, List<CommentModel>>.from(state.replies);

    for (final entry in state.replies.entries) {
      final replyIndex = entry.value.indexWhere((reply) => reply.id == commentId);
      if (replyIndex != -1) {
        parentCommentId = entry.key;
        removedReplyIndex = replyIndex;
        removedReply = entry.value[replyIndex];
        final newReplies = List<CommentModel>.from(entry.value)
          ..removeAt(replyIndex);
        updatedReplies[entry.key] = newReplies;
        break;
      }
    }

    if (parentCommentId == null || removedReply == null) {
      return;
    }

    final updatedComments = state.comments.map((comment) {
      if (comment.id == parentCommentId) {
        return comment.copyWith(
          replyCount: (comment.replyCount - 1).clamp(0, 1 << 31),
        );
      }
      return comment;
    }).toList();

    state = state.copyWith(
      comments: updatedComments,
      replies: updatedReplies,
      errorMessage: null,
    );

    try {
      await _commentService.deleteComment(commentId);
      _ref.read(feedProvider.notifier).decrementCommentCount(postId);
    } catch (e) {
      final restoredReplies = Map<String, List<CommentModel>>.from(state.replies);
      final parentReplies = List<CommentModel>.from(
        restoredReplies[parentCommentId] ?? const [],
      );
      parentReplies.insert(removedReplyIndex, removedReply);
      restoredReplies[parentCommentId] = parentReplies;

      final restoredComments = state.comments.map((comment) {
        if (comment.id == parentCommentId) {
          return comment.copyWith(replyCount: comment.replyCount + 1);
        }
        return comment;
      }).toList();

      state = state.copyWith(
        comments: restoredComments,
        replies: restoredReplies,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── SET REPLYING TO ─────────────────────────────────────
  void setReplyingTo(CommentModel? comment) {
    state = state.copyWith(
      replyingTo: comment,
      clearReplyingTo: comment == null,
    );
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final commentServiceProvider = Provider<CommentService>((ref) {
  return CommentService();
});

// Family provider: one per post
final commentProvider =
    StateNotifierProvider.family<CommentNotifier, CommentState, String>((
      ref,
      postId,
    ) {
      return CommentNotifier(ref.watch(commentServiceProvider), postId, ref);
    });
