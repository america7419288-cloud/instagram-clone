// server/src/controllers/comment.controller.js

const {
  Comment,
  CommentLike,
  User,
  Post,
  sequelize,
} = require('../models');
const {
  successResponse,
  errorResponse,
  paginatedResponse,
} = require('../utils/response.utils');
const {
  notifyComment,
  notifyReply,
  notifyCommentLike,
  processMentions,
} = require('../services/notification.service');
const { Op } = require('sequelize');

// ─── HELPER: Format comment ────────────────────────────────
const formatComment = (comment, currentUserId = null) => {
  const c = comment.toJSON ? comment.toJSON() : comment;

  return {
    id: c.id,
    content: c.content,
    is_pinned: c.is_pinned,
    created_at: c.created_at || c.createdAt,
    updated_at: c.updated_at || c.updatedAt,

    // Who wrote it
    user: c.user
      ? {
          id: c.user.id,
          username: c.user.username,
          full_name: c.user.full_name,
          profile_pic_url: c.user.profile_pic_url,
          is_verified: c.user.is_verified,
        }
      : null,

    // Counts
    like_count: c.like_count || 0,
    reply_count: c.reply_count || 0,

    // Current user interaction
    is_liked: c.is_liked || false,
    is_own_comment: currentUserId
      ? c.user?.id === currentUserId
      : false,

    // Parent comment id (for replies)
    parent_comment_id: c.parent_comment_id || null,
  };
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/posts/:id/comments
// @desc    Add a comment to a post
// @access  Private
// ─────────────────────────────────────────────────────────────
const addComment = async (req, res) => {
  try {
    const { id: postId } = req.params;
    const userId = req.user.id;
    const { content, parent_comment_id } = req.body;

    // 1. VALIDATE CONTENT
    if (!content || content.trim().length === 0) {
      return errorResponse(res, 400, 'Comment content is required.');
    }

    if (content.trim().length > 2200) {
      return errorResponse(
        res, 400,
        'Comment cannot exceed 2200 characters.'
      );
    }

    // 2. CHECK POST EXISTS
    const post = await Post.findOne({
      where: { id: postId, is_archived: false },
    });

    if (!post) {
      return errorResponse(res, 404, 'Post not found.');
    }

    // 3. CHECK IF COMMENTS ARE DISABLED
    if (post.comments_disabled) {
      return errorResponse(
        res, 403,
        'Comments are disabled for this post.'
      );
    }

    // 4. IF REPLY: CHECK PARENT COMMENT EXISTS
    let parentComment = null;
    if (parent_comment_id) {
      parentComment = await Comment.findOne({
        where: {
          id: parent_comment_id,
          post_id: postId, // Must be on same post
        },
      });

      if (!parentComment) {
        return errorResponse(
          res, 404,
          'Parent comment not found.'
        );
      }
    }

    // 5. CREATE COMMENT
    const comment = await Comment.create({
      post_id: postId,
      user_id: userId,
      content: content.trim(),
      parent_comment_id: parent_comment_id || null,
    });

    if (parentComment) {
      if (parentComment.user_id !== userId) {
        notifyReply(userId, comment.id, parentComment.post_id, parentComment.user_id);
      }
    } else {
      notifyComment(userId, postId, comment.id);
    }

    processMentions(content.trim(), userId, postId, comment.id);

    // 6. FETCH WITH USER DATA
    const fullComment = await Comment.findByPk(comment.id, {
      include: [
        {
          model: User,
          as: 'user',
          attributes: [
            'id', 'username', 'full_name',
            'profile_pic_url', 'is_verified',
          ],
        },
      ],
    });

    const commentData = fullComment.toJSON();
    commentData.like_count = 0;
    commentData.reply_count = 0;
    commentData.is_liked = false;

    console.log(`💬 Comment added to post ${postId} by ${userId}`);

    return successResponse(
      res, 201,
      'Comment added successfully! 💬',
      { comment: formatComment(commentData, userId) }
    );

  } catch (error) {
    console.error('❌ Add comment error:', error);
    return errorResponse(res, 500, 'Failed to add comment.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/posts/:id/comments
// @desc    Get comments for a post (top-level only, paginated)
// @access  Private
// ─────────────────────────────────────────────────────────────
const getComments = async (req, res) => {
  try {
    const { id: postId } = req.params;
    const currentUserId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    // Check post exists
    const post = await Post.findByPk(postId);
    if (!post) {
      return errorResponse(res, 404, 'Post not found.');
    }

    // Get top-level comments only (parent_comment_id = null)
    // Pinned comments first, then newest
    const { count, rows: comments } = await Comment.findAndCountAll({
      where: {
        post_id: postId,
        parent_comment_id: null, // Top-level only
        is_hidden: false,
      },
      include: [
        {
          model: User,
          as: 'user',
          attributes: [
            'id', 'username', 'full_name',
            'profile_pic_url', 'is_verified',
          ],
        },
      ],
      order: [
        ['is_pinned', 'DESC'], // Pinned first
        ['created_at', 'ASC'], // Then oldest to newest
      ],
      limit,
      offset,
      distinct: true,
    });

    // Get comment IDs for batch queries
    const commentIds = comments.map((c) => c.id);

    // Get like counts for all comments
    const likeCounts = await CommentLike.findAll({
      where: { comment_id: { [Op.in]: commentIds } },
      attributes: [
        'comment_id',
        [sequelize.fn('COUNT', sequelize.col('id')), 'count'],
      ],
      group: ['comment_id'],
      raw: true,
    });

    // Get reply counts for all comments
    const replyCounts = await Comment.findAll({
      where: {
        parent_comment_id: { [Op.in]: commentIds },
        is_hidden: false,
      },
      attributes: [
        'parent_comment_id',
        [sequelize.fn('COUNT', sequelize.col('id')), 'count'],
      ],
      group: ['parent_comment_id'],
      raw: true,
    });

    // Get current user's liked comments
    const userLikes = await CommentLike.findAll({
      where: {
        user_id: currentUserId,
        comment_id: { [Op.in]: commentIds },
      },
      attributes: ['comment_id'],
      raw: true,
    });

    // Build lookup maps
    const likeCountMap = {};
    likeCounts.forEach((l) => {
      likeCountMap[l.comment_id] = parseInt(l.count);
    });

    const replyCountMap = {};
    replyCounts.forEach((r) => {
      replyCountMap[r.parent_comment_id] = parseInt(r.count);
    });

    const likedCommentIds = new Set(
      userLikes.map((l) => l.comment_id)
    );

    // Format comments
    const formattedComments = comments.map((comment) => {
      const c = comment.toJSON();
      c.like_count = likeCountMap[comment.id] || 0;
      c.reply_count = replyCountMap[comment.id] || 0;
      c.is_liked = likedCommentIds.has(comment.id);
      return formatComment(c, currentUserId);
    });

    return paginatedResponse(
      res,
      'Comments fetched successfully',
      formattedComments,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get comments error:', error);
    return errorResponse(res, 500, 'Failed to fetch comments.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/comments/:id/replies
// @desc    Get replies for a specific comment
// @access  Private
// ─────────────────────────────────────────────────────────────
const getReplies = async (req, res) => {
  try {
    const { id: commentId } = req.params;
    const currentUserId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const offset = (page - 1) * limit;

    // Verify parent comment exists
    const parentComment = await Comment.findByPk(commentId);
    if (!parentComment) {
      return errorResponse(res, 404, 'Comment not found.');
    }

    const { count, rows: replies } = await Comment.findAndCountAll({
      where: {
        parent_comment_id: commentId,
        is_hidden: false,
      },
      include: [
        {
          model: User,
          as: 'user',
          attributes: [
            'id', 'username', 'full_name',
            'profile_pic_url', 'is_verified',
          ],
        },
      ],
      order: [['created_at', 'ASC']],
      limit,
      offset,
    });

    const replyIds = replies.map((r) => r.id);

    // Get like counts
    const likeCounts = await CommentLike.findAll({
      where: { comment_id: { [Op.in]: replyIds } },
      attributes: [
        'comment_id',
        [sequelize.fn('COUNT', sequelize.col('id')), 'count'],
      ],
      group: ['comment_id'],
      raw: true,
    });

    const userLikes = await CommentLike.findAll({
      where: {
        user_id: currentUserId,
        comment_id: { [Op.in]: replyIds },
      },
      attributes: ['comment_id'],
      raw: true,
    });

    const likeCountMap = {};
    likeCounts.forEach((l) => {
      likeCountMap[l.comment_id] = parseInt(l.count);
    });

    const likedIds = new Set(userLikes.map((l) => l.comment_id));

    const formattedReplies = replies.map((reply) => {
      const r = reply.toJSON();
      r.like_count = likeCountMap[reply.id] || 0;
      r.reply_count = 0;
      r.is_liked = likedIds.has(reply.id);
      return formatComment(r, currentUserId);
    });

    return paginatedResponse(
      res,
      'Replies fetched',
      formattedReplies,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get replies error:', error);
    return errorResponse(res, 500, 'Failed to fetch replies.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   PUT /api/v1/comments/:id
// @desc    Edit a comment
// @access  Private (own comment only)
// ─────────────────────────────────────────────────────────────
const editComment = async (req, res) => {
  try {
    const { id: commentId } = req.params;
    const userId = req.user.id;
    const { content } = req.body;

    if (!content || content.trim().length === 0) {
      return errorResponse(res, 400, 'Comment content is required.');
    }

    const comment = await Comment.findByPk(commentId);

    if (!comment) {
      return errorResponse(res, 404, 'Comment not found.');
    }

    // Only comment owner can edit
    if (comment.user_id !== userId) {
      return errorResponse(
        res, 403,
        'You can only edit your own comments.'
      );
    }

    await comment.update({ content: content.trim() });

    return successResponse(res, 200, 'Comment updated.', {
      comment: {
        id: comment.id,
        content: comment.content,
        updated_at: comment.updatedAt,
      },
    });

  } catch (error) {
    console.error('❌ Edit comment error:', error);
    return errorResponse(res, 500, 'Failed to edit comment.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/comments/:id
// @desc    Delete a comment
// @access  Private (own comment OR post owner)
// ─────────────────────────────────────────────────────────────
const deleteComment = async (req, res) => {
  try {
    const { id: commentId } = req.params;
    const userId = req.user.id;

    const comment = await Comment.findOne({
      where: { id: commentId },
      include: [{ model: Post, as: 'post', attributes: ['user_id'] }],
    });

    if (!comment) {
      return errorResponse(res, 404, 'Comment not found.');
    }

    // Can delete if:
    // 1. You own the comment
    // 2. You own the post the comment is on
    const isCommentOwner = comment.user_id === userId;
    const isPostOwner = comment.post?.user_id === userId;

    if (!isCommentOwner && !isPostOwner) {
      return errorResponse(
        res, 403,
        'You cannot delete this comment.'
      );
    }

    // Delete comment (cascade deletes replies + likes)
    await comment.destroy();

    console.log(`🗑️  Comment deleted: ${commentId}`);

    return successResponse(
      res, 200,
      'Comment deleted successfully.',
      {}
    );

  } catch (error) {
    console.error('❌ Delete comment error:', error);
    return errorResponse(res, 500, 'Failed to delete comment.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/comments/:id/like
// @desc    Like a comment
// @access  Private
// ─────────────────────────────────────────────────────────────
const likeComment = async (req, res) => {
  try {
    const { id: commentId } = req.params;
    const userId = req.user.id;

    const comment = await Comment.findByPk(commentId);
    if (!comment) {
      return errorResponse(res, 404, 'Comment not found.');
    }

    const [like, created] = await CommentLike.findOrCreate({
      where: { user_id: userId, comment_id: commentId },
    });

    if (!created) {
      return errorResponse(
        res, 400,
        'You already liked this comment.'
      );
    }

    const commentToNotify = await Comment.findByPk(commentId, {
      include: [{ model: Post, as: 'post' }],
    });
    if (commentToNotify) {
      notifyCommentLike(
        userId,
        commentId,
        commentToNotify.user_id,
        commentToNotify.post_id
      );
    }

    const likeCount = await CommentLike.count({
      where: { comment_id: commentId },
    });

    return successResponse(res, 200, 'Comment liked! ❤️', {
      comment_id: commentId,
      like_count: likeCount,
      is_liked: true,
    });

  } catch (error) {
    console.error('❌ Like comment error:', error);
    return errorResponse(res, 500, 'Failed to like comment.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/comments/:id/like
// @desc    Unlike a comment
// @access  Private
// ─────────────────────────────────────────────────────────────
const unlikeComment = async (req, res) => {
  try {
    const { id: commentId } = req.params;
    const userId = req.user.id;

    const deleted = await CommentLike.destroy({
      where: { user_id: userId, comment_id: commentId },
    });

    if (deleted === 0) {
      return errorResponse(
        res, 400,
        'You have not liked this comment.'
      );
    }

    const likeCount = await CommentLike.count({
      where: { comment_id: commentId },
    });

    return successResponse(res, 200, 'Comment unliked.', {
      comment_id: commentId,
      like_count: likeCount,
      is_liked: false,
    });

  } catch (error) {
    console.error('❌ Unlike comment error:', error);
    return errorResponse(res, 500, 'Failed to unlike comment.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/comments/:id/pin
// @desc    Pin a comment (post owner only)
// @access  Private
// ─────────────────────────────────────────────────────────────
const pinComment = async (req, res) => {
  try {
    const { id: commentId } = req.params;
    const userId = req.user.id;

    const comment = await Comment.findOne({
      where: { id: commentId },
      include: [{ model: Post, as: 'post', attributes: ['user_id', 'id'] }],
    });

    if (!comment) {
      return errorResponse(res, 404, 'Comment not found.');
    }

    // Only post owner can pin
    if (comment.post?.user_id !== userId) {
      return errorResponse(
        res, 403,
        'Only the post owner can pin comments.'
      );
    }

    // Unpin any currently pinned comment on this post
    await Comment.update(
      { is_pinned: false },
      { where: { post_id: comment.post_id, is_pinned: true } }
    );

    // Pin this comment
    await comment.update({ is_pinned: true });

    return successResponse(res, 200, 'Comment pinned! 📌', {
      comment_id: commentId,
      is_pinned: true,
    });

  } catch (error) {
    console.error('❌ Pin comment error:', error);
    return errorResponse(res, 500, 'Failed to pin comment.');
  }
};

module.exports = {
  addComment,
  getComments,
  getReplies,
  editComment,
  deleteComment,
  likeComment,
  unlikeComment,
  pinComment,
};
