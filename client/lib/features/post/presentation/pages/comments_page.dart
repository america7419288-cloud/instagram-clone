// lib/features/post/presentation/pages/comments_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/post_model.dart';
import '../../data/models/comment_model.dart';
import '../providers/comment_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../../shared/widgets/user_story_avatar.dart';
import '../../../../features/menu/presentation/three_dot_menu.dart';
import '../../../../features/menu/models/menu_context.dart';
import '../../../../features/menu/models/menu_action.dart';
import '../../../../shared/widgets/mention_text_field.dart';



class CommentsPage extends ConsumerStatefulWidget {
  final String postId;
  final PostModel? post;
  final bool isBottomSheet;

  const CommentsPage({
    super.key,
    required this.postId,
    this.post,
    this.isBottomSheet = false,
  });

  @override
  ConsumerState<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends ConsumerState<CommentsPage> {
  final MentionTextFieldController _commentController = MentionTextFieldController();
  final FocusNode _commentFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<String> _quickEmojis = ['❤️', '🙌', '🔥', '👏', '😢', '😍', '😮', '😂'];

  @override
  void initState() {
    super.initState();
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(commentProvider(widget.postId).notifier).loadMore();
    }
  }

  Future<void> _submitComment([String? customContent]) async {
    final content = customContent ?? _commentController.text.trim();
    if (content.isEmpty) return;

    final notifier = ref.read(commentProvider(widget.postId).notifier);
    final state = ref.read(commentProvider(widget.postId));

    _commentController.clear();
    if (customContent == null) _commentFocus.unfocus();

    bool success;
    if (state.replyingTo != null) {
      success = await notifier.replyToComment(state.replyingTo!.id, content);
    } else {
      success = await notifier.addComment(content);
    }
    
    if (success && _scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _handleMenuAction(CommentModel comment, MenuAction action) {
    switch (action.type) {
      case MenuActionType.delete:
        ref.read(commentProvider(widget.postId).notifier).deleteComment(comment.id);
        break;
      case MenuActionType.copyLink:
        Clipboard.setData(ClipboardData(text: comment.content));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
        break;
      case MenuActionType.report:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment reported')),
        );
        break;
      default:
        break;
    }
  }

  void _showCommentMenu(CommentModel comment) {
    final menuContext = MenuContext(
      contentId: comment.id,
      contentType: MenuContentType.comment,
      relationship: comment.isOwnComment ? MenuRelationship.owner : MenuRelationship.notFollowing,
      authorUsername: comment.user?.username,
      authorId: comment.user?.id,
      authorAvatarUrl: comment.user?.profilePicUrl,
      canDelete: comment.isOwnComment,
    );

    InstagramMenu.show(
      context,
      menuContext: menuContext,
      onAction: (action) => _handleMenuAction(comment, action),
    );
  }


  @override
  Widget build(BuildContext context) {
    final commentState = ref.watch(commentProvider(widget.postId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: widget.isBottomSheet ? Colors.transparent : (isDark ? Colors.black : Colors.white),
      appBar: widget.isBottomSheet ? null : CupertinoNavigationBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.grey[900]! : Colors.grey[300]!, width: 0.5)),
        leading: BouncyTap(
          onTap: () => context.pop(),
          child: const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Icon(LucideIcons.chevron_left, color: AppColors.primary),
          ),
        ),
        middle: const Text(
          'Comments',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'SF Pro Text'),
        ),
        trailing: BouncyTap(
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Icon(LucideIcons.send, size: 24, color: AppColors.primary),
          ),
        ),
      ),
      body: Column(
        children: [
          if (widget.isBottomSheet)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Comments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          if (widget.isBottomSheet)
            Divider(height: 0.5, color: isDark ? Colors.grey[900] : Colors.grey[300]),
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Post Caption
                if (widget.post != null)
                  SliverToBoxAdapter(
                    child: _CaptionItem(post: widget.post!),
                  ),

                if (widget.post != null)
                   const SliverToBoxAdapter(child: Divider(height: 0.5)),

                // Comments List
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final comment = commentState.comments[index];
                      final replies = commentState.replies[comment.id] ?? [];
                      final isLoadingReplies = commentState.loadingReplies[comment.id] ?? false;

                      return _CommentThread(
                        comment: comment,
                        replies: replies,
                        isLoadingReplies: isLoadingReplies,
                        isDark: isDark,
                        onReply: () {
                          ref.read(commentProvider(widget.postId).notifier).setReplyingTo(comment);
                          _commentFocus.requestFocus();
                          _commentController.text = '@${comment.user?.username} ';
                        },
                        onLoadReplies: () => ref.read(commentProvider(widget.postId).notifier).loadReplies(comment.id),
                        onLike: () => ref.read(commentProvider(widget.postId).notifier).toggleCommentLike(comment.id),
                        onLongPress: () => _showCommentMenu(comment),
                        onReplyLongPress: (reply) => _showCommentMenu(reply),
                      );

                    },
                    childCount: commentState.comments.length,
                  ),
                ),
                
                if (commentState.isLoadingMore)
                   const SliverToBoxAdapter(
                     child: Padding(
                       padding: EdgeInsets.symmetric(vertical: 20),
                       child: CupertinoActivityIndicator(),
                     ),
                   ),
              ],
            ),
          ),
          _buildCommentInput(commentState, isDark),
        ],
      ),
    );
  }

  Widget _buildCommentInput(CommentState state, bool isDark) {
    final currentUser = ref.watch(authProvider).user;
    final textBorderColor = isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.7),
        border: Border(top: BorderSide(color: textBorderColor, width: 0.5)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji Row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _quickEmojis.map((e) => BouncyTap(
                onTap: () => _submitComment(e),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              )).toList(),
            ),
          ),
          
          if (state.replyingTo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to @${state.replyingTo!.user?.username}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                  BouncyTap(
                    onTap: () => ref.read(commentProvider(widget.postId).notifier).setReplyingTo(null),
                    child: Icon(LucideIcons.x, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: [
                UserStoryAvatar(
                  userId: currentUser?.id ?? '',
                  profilePicUrl: currentUser?.profilePicUrl,
                  username: currentUser?.username,
                  size: 32,
                  isClickable: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: textBorderColor, width: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: MentionTextField(
                            controller: _commentController,
                            focusNode: _commentFocus,
                            contextType: 'comment',
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black, fontFamily: 'SF Pro Text'),
                            maxLines: 4,
                            minLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder(
                          valueListenable: _commentController,
                          builder: (context, value, _) {
                            final isEmpty = value.text.trim().isEmpty;
                            return BouncyTap(
                              onTap: isEmpty ? null : () => _submitComment(),
                              child: Text(
                                'Post',
                                style: TextStyle(
                                  color: isEmpty 
                                      ? (isDark ? Colors.white30 : Colors.black38)
                                      : const Color(0xFF0095F6),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionItem extends StatelessWidget {
  final PostModel post;
  const _CaptionItem({required this.post});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BouncyTap(
            onTap: () => context.push('/profile/${post.user?.username}'),
            child: UserStoryAvatar(
              userId: post.userId,
              profilePicUrl: post.userAvatar,
              username: post.username,
              size: 32,
              showPresence: false,
              isClickable: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontFamily: 'SF Pro Text'),
                    children: [
                      TextSpan(text: '${post.user?.username} ', style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (post.user?.isVerified ?? false)
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: VerifiedBadge(size: 11),
                        ),
                      if (post.user?.isVerified ?? false)
                        const TextSpan(text: ' '),
                      TextSpan(text: post.caption ?? ''),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('Today', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentThread extends StatelessWidget {
  final CommentModel comment;
  final List<CommentModel> replies;
  final bool isLoadingReplies;
  final bool isDark;
  final VoidCallback onReply;
  final VoidCallback onLoadReplies;
  final VoidCallback onLike;
  final VoidCallback onLongPress;
  final Function(CommentModel) onReplyLongPress;

  const _CommentThread({
    required this.comment,
    required this.replies,
    required this.isLoadingReplies,
    required this.isDark,
    required this.onReply,
    required this.onLoadReplies,
    required this.onLike,
    required this.onLongPress,
    required this.onReplyLongPress,
  });


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentRow(
          comment: comment,
          isDark: isDark,
          onReply: onReply,
          onLike: onLike,
          onLongPress: onLongPress,
        ),

        
        if (comment.replyCount > 0 && !comment.repliesExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 60, bottom: 8),
            child: BouncyTap(
              onTap: onLoadReplies,
              child: Row(
                children: [
                  Container(width: 24, height: 1, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text('View ${comment.replyCount} replies', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

        if (comment.repliesExpanded)
          ...replies.map((r) => Padding(
            padding: const EdgeInsets.only(left: 54),
            child: _CommentRow(
              comment: r,
              isDark: isDark,
              isReply: true,
              onReply: onReply,
              onLike: onLike,
              onLongPress: () => onReplyLongPress(r),
            ),
          )),

          
        if (comment.repliesExpanded && isLoadingReplies)
           const Padding(
             padding: EdgeInsets.only(left: 60, bottom: 8),
             child: CupertinoActivityIndicator(radius: 8),
           ),
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  final CommentModel comment;
  final bool isDark;
  final bool isReply;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback? onLongPress;

  const _CommentRow({
    required this.comment,
    required this.isDark,
    this.isReply = false,
    required this.onReply,
    required this.onLike,
    this.onLongPress,
  });


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BouncyTap(
            onTap: () => context.push('/profile/${comment.user?.username}'),
            child: UserStoryAvatar(
              userId: comment.user?.id ?? '',
              profilePicUrl: comment.user?.profilePicUrl,
              username: comment.user?.username,
              size: isReply ? 24 : 32,
              showPresence: false,
              isClickable: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontFamily: 'SF Pro Text'),
                    children: [
                      TextSpan(text: '${comment.user?.username} ', style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (comment.user?.isVerified ?? false)
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: VerifiedBadge(size: 11),
                        ),
                      if (comment.user?.isVerified ?? false)
                        const TextSpan(text: ' '),
                      TextSpan(text: comment.content),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('2h', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(width: 12),
                    BouncyTap(onTap: onReply, child: const Text('Reply', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BouncyTap(
            onTap: onLike,
            child: Column(
              children: [
                  Icon(
                    comment.isLiked ? LucideIcons.heart : LucideIcons.heart,
                    size: 14,
                    fill: comment.isLiked ? 1.0 : 0.0,
                    color: comment.isLiked ? Colors.red : Colors.grey,
                  ),
                if (comment.likeCount > 0)
                  Text('${comment.likeCount}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
