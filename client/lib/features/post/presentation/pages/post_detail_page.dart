// lib/features/post/presentation/pages/post_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/router/navigation_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../follow/data/repositories/presentation/providers/widgets/follow_button.dart';
import '../../data/models/post_model.dart';
import '../../data/models/comment_model.dart';
import '../../data/repositories/post_service.dart';
import '../providers/feed_provider.dart';
import '../providers/comment_provider.dart';
import '../widgets/video_player_widget.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  PostModel? _post;
  bool _isLoadingPost = true;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPost();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more comments near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(commentProvider(widget.postId).notifier).loadMore();
    }
  }

  Future<void> _loadPost() async {
    try {
      final post = await PostService().getPost(widget.postId);
      if (mounted) {
        setState(() {
          _post = post;
          _isLoadingPost = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPost = false);
      }
    }
  }

  // ─── SUBMIT COMMENT ───────────────────────────────────────
  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final commentState = ref.read(commentProvider(widget.postId));
    final notifier = ref.read(commentProvider(widget.postId).notifier);

    _commentController.clear();
    _commentFocus.unfocus();

    bool success;
    if (commentState.replyingTo != null) {
      success = await notifier.replyToComment(
        commentState.replyingTo!.id,
        content,
      );
    } else {
      success = await notifier.addComment(content);
    }

    if (success && mounted) {
      // Scroll to top to see new comment
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ─── TOGGLE LIKE POST ─────────────────────────────────────
  void _toggleLike() {
    if (_post != null) {
      ref.read(feedProvider.notifier).toggleLike(_post!.id);
      setState(() {
        _post = _post!.copyWith(
          isLiked: !_post!.isLiked,
          likeCount: _post!.isLiked
              ? _post!.likeCount - 1
              : _post!.likeCount + 1,
        );
      });
    }
  }

  // ─── TOGGLE SAVE POST ─────────────────────────────────────
  void _toggleSave() {
    if (_post != null) {
      ref.read(feedProvider.notifier).toggleSave(_post!.id);
      setState(() {
        _post = _post!.copyWith(isSaved: !_post!.isSaved);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentState = ref.watch(commentProvider(widget.postId));

    return Scaffold(
      backgroundColor: AppColors.white,

      // ─── APP BAR ────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
        title: const Text(
          'Post',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz, color: AppColors.textPrimary),
          ),
        ],
      ),

      // ─── BODY ───────────────────────────────────────────
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: _isLoadingPost
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _post == null
                ? const Center(child: Text('Post not found'))
                : CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Post header + image + actions
                      SliverToBoxAdapter(child: _buildPostSection(_post!)),

                      // Comments divider
                      const SliverToBoxAdapter(
                        child: Divider(height: 1, color: AppColors.border),
                      ),

                      // Comments header
                      SliverToBoxAdapter(
                        child: _buildCommentsHeader(commentState),
                      ),

                      // Comments list
                      _buildCommentsList(commentState),

                      // Loading more indicator
                      SliverToBoxAdapter(
                        child: commentState.isLoadingMore
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : const SizedBox(height: 80),
                      ),
                    ],
                  ),
          ),

          // Comment input (always at bottom)
          if (_post != null && !_post!.commentsDisabled)
            _buildCommentInput(commentState),
        ],
      ),
    );
  }

  // ─── POST SECTION (image + actions + caption) ─────────────
  Widget _buildPostSection(PostModel post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User header
        _buildPostHeader(post),

        // Image carousel
        if (post.media.isNotEmpty) _buildImageSection(post),

        // Action buttons
        _buildPostActions(post),

        // Likes count
        if (post.likeCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: GestureDetector(
              onTap: () => context.pushIfNotCurrent('/post/${post.id}/likes'),
              child: Text(
                '${_formatCount(post.likeCount)} likes',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),

        // Caption
        if (post.caption != null && post.caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '${post.user?.username ?? ''} ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  ..._buildCaptionSpans(post.caption!),
                ],
              ),
            ),
          ),

        // Timestamp
        if (post.createdAt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Text(
              timeago.format(post.createdAt!),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPostHeader(PostModel post) {
    final author = post.user;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (author != null) {
                context.pushIfNotCurrent('/profile/${author.username}');
              }
            },
            child: _buildAvatar(author?.profilePicUrl, 36),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author?.username ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (post.location != null)
                  Text(
                    post.location!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (!post.isOwnPost && author != null && author.id.isNotEmpty) ...[
            FollowButton(targetUserId: author.id, compact: true),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.more_horiz),
        ],
      ),
    );
  }

  Widget _buildImageSection(PostModel post) {
    return Stack(
      children: [
        SizedBox(
          height: 400,
          child: post.isCarousel
              ? PageView.builder(
                  itemCount: post.media.length,
                  onPageChanged: (i) => setState(() => _currentImageIndex = i),
                  itemBuilder: (_, i) => _buildMediaItem(post.media[i]),
                )
              : _buildMediaItem(post.media.first),
        ),

        // Carousel dots
        if (post.isCarousel)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                post.media.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentImageIndex == i ? 8 : 6,
                  height: _currentImageIndex == i ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == i
                        ? AppColors.primary
                        : Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaItem(PostMediaModel media) {
    if (media.isVideo) {
      return VideoPlayerWidget(
        videoUrl: media.url,
        thumbnailUrl: media.thumbnailUrl,
        duration: media.duration,
        autoPlay: true,
        showControls: true,
        looping: true,
        fit: BoxFit.cover,
      );
    }

    return CachedNetworkImage(
      imageUrl: media.feedUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (_, __) => Container(color: AppColors.border),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.border,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }

  Widget _buildPostActions(PostModel post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          // Like
          IconButton(
            onPressed: _toggleLike,
            icon: Icon(
              post.isLiked ? Icons.favorite : Icons.favorite_border,
              color: post.isLiked ? AppColors.secondary : AppColors.textPrimary,
              size: 26,
            ),
          ),
          // Comment
          IconButton(
            onPressed: () => _commentFocus.requestFocus(),
            icon: const Icon(
              Icons.chat_bubble_outline,
              size: 24,
              color: AppColors.textPrimary,
            ),
          ),
          // Share
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.send_outlined,
              size: 24,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          // Save
          IconButton(
            onPressed: _toggleSave,
            icon: Icon(
              post.isSaved ? Icons.bookmark : Icons.bookmark_border,
              size: 26,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── COMMENTS HEADER ─────────────────────────────────────
  Widget _buildCommentsHeader(CommentState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            state.comments.isEmpty
                ? 'No comments yet'
                : '${state.comments.length} comments',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (state.isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }

  // ─── COMMENTS LIST ────────────────────────────────────────
  Widget _buildCommentsList(CommentState commentState) {
    if (commentState.comments.isEmpty && !commentState.isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: AppColors.border,
              ),
              const SizedBox(height: 12),
              const Text(
                'No comments yet.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start the conversation.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final comment = commentState.comments[index];
        final replies = commentState.replies[comment.id] ?? [];
        final isLoadingReplies =
            commentState.loadingReplies[comment.id] ?? false;

        return _CommentItem(
          comment: comment,
          replies: replies,
          isLoadingReplies: isLoadingReplies,
          onLike: () => ref
              .read(commentProvider(widget.postId).notifier)
              .toggleCommentLike(comment.id),
          onReply: () {
            ref
                .read(commentProvider(widget.postId).notifier)
                .setReplyingTo(comment);
            _commentFocus.requestFocus();
          },
          onLoadReplies: () => ref
              .read(commentProvider(widget.postId).notifier)
              .loadReplies(comment.id),
          onDelete: comment.isOwnComment
              ? () => _confirmDeleteComment(comment.id)
              : null,
          onReplyLike: (replyId) => ref
              .read(commentProvider(widget.postId).notifier)
              .toggleCommentLike(replyId),
        );
      }, childCount: commentState.comments.length),
    );
  }

  // ─── COMMENT INPUT ────────────────────────────────────────
  Widget _buildCommentInput(CommentState commentState) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply indicator
            if (commentState.replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: AppColors.background,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to @${commentState.replyingTo!.user?.username ?? ''}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => ref
                          .read(commentProvider(widget.postId).notifier)
                          .setReplyingTo(null),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Input row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // User avatar
                  _buildAvatar(null, 32),
                  const SizedBox(width: 10),

                  // Text field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              focusNode: _commentFocus,
                              decoration: InputDecoration(
                                hintText: commentState.replyingTo != null
                                    ? 'Reply to @${commentState.replyingTo!.user?.username ?? ''}...'
                                    : 'Add a comment...',
                                hintStyle: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (_) => _submitComment(),
                            ),
                          ),
                          // Emoji
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.emoji_emotions_outlined,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Post button
                  commentState.isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : GestureDetector(
                          onTap: _submitComment,
                          child: const Text(
                            'Post',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CONFIRM DELETE ───────────────────────────────────────
  Future<void> _confirmDeleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Comment'),
        content: const Text(
          'Are you sure you want to delete this comment?'
          ' This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(commentProvider(widget.postId).notifier)
          .deleteComment(commentId);
    }
  }

  // ─── HELPERS ─────────────────────────────────────────────
  Widget _buildAvatar(String? imageUrl, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 0.5),
        color: AppColors.border,
      ),
      child: ClipOval(
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.person, color: AppColors.textSecondary),
              )
            : const Icon(Icons.person, color: AppColors.textSecondary),
      ),
    );
  }

  List<TextSpan> _buildCaptionSpans(String text) {
    final spans = <TextSpan>[];
    final parts = text.split(RegExp(r'(#\w+)'));
    for (final part in parts) {
      if (part.startsWith('#')) {
        spans.add(
          TextSpan(
            text: part,
            style: const TextStyle(color: AppColors.primary),
          ),
        );
      } else {
        spans.add(TextSpan(text: part));
      }
    }
    return spans;
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

// ─── COMMENT ITEM WIDGET ────────────────────────────────────
class _CommentItem extends StatelessWidget {
  final CommentModel comment;
  final List<CommentModel> replies;
  final bool isLoadingReplies;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onLoadReplies;
  final VoidCallback? onDelete;
  final Function(String) onReplyLike;

  const _CommentItem({
    required this.comment,
    required this.replies,
    required this.isLoadingReplies,
    required this.onLike,
    required this.onReply,
    required this.onLoadReplies,
    this.onDelete,
    required this.onReplyLike,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main comment
        _buildCommentRow(
          context: context,
          comment: comment,
          isReply: false,
          onLike: onLike,
          onReply: onReply,
          onDelete: onDelete,
        ),

        // View replies button
        if (comment.replyCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 64, bottom: 8),
            child: GestureDetector(
              onTap: onLoadReplies,
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 1,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  isLoadingReplies
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : Text(
                          comment.repliesExpanded
                              ? 'Hide replies'
                              : 'View ${comment.replyCount} ${comment.replyCount == 1 ? 'reply' : 'replies'}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ],
              ),
            ),
          ),

        // Replies
        if (comment.repliesExpanded)
          ...replies.map(
            (reply) => Padding(
              padding: const EdgeInsets.only(left: 48),
              child: _buildCommentRow(
                context: context,
                comment: reply,
                isReply: true,
                onLike: () => onReplyLike(reply.id),
                onReply: onReply,
                onDelete: reply.isOwnComment ? onDelete : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentRow({
    required BuildContext context,
    required CommentModel comment,
    required bool isReply,
    required VoidCallback onLike,
    required VoidCallback onReply,
    VoidCallback? onDelete,
  }) {
    final timeText = comment.createdAt != null
        ? timeago.format(comment.createdAt!, locale: 'en_short')
        : '';

    return Padding(
      padding: EdgeInsets.fromLTRB(12, isReply ? 4 : 8, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          GestureDetector(
            onTap: () {
              if (comment.user != null) {
                context.pushIfNotCurrent('/profile/${comment.user!.username}');
              }
            },
            child: Container(
              width: isReply ? 28 : 36,
              height: isReply ? 28 : 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.border,
              ),
              child: ClipOval(
                child: comment.user?.profilePicUrl != null
                    ? CachedNetworkImage(
                        imageUrl: comment.user!.profilePicUrl!,
                        fit: BoxFit.cover,
                      )
                    : const Icon(
                        Icons.person,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pinned badge
                if (comment.isPinned)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.border.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.push_pin,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Pinned',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Username + content
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: '${comment.user?.username ?? ''} ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: comment.content),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Time + Reply + Like count
                Row(
                  children: [
                    Text(
                      timeText,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (comment.likeCount > 0)
                      Text(
                        '${comment.likeCount} ${comment.likeCount == 1 ? 'like' : 'likes'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (comment.likeCount > 0) const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onReply,
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Like button
          GestureDetector(
            onTap: onLike,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Icon(
                comment.isLiked ? Icons.favorite : Icons.favorite_border,
                size: 14,
                color: comment.isLiked
                    ? AppColors.secondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
