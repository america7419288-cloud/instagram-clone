// server/src/controllers/comment.controller.js

const {
  Comment,
  CommentLike,
  User,
  Post,
  Block,
  sequelize,
} = require('../models');
const { getBlockedUserIds } = require('../utils/block.utils');
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
          full_name: c.user.fullName || c.user.full_name,
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
    parent_comment_id: c.parentCommentId || null,
    post_id: c.postId,
    mentions: c.mentions || [],
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

    // 2.1 CHECK IF BLOCKED
    const blockedUserIds = await getBlockedUserIds(userId);
    if (blockedUserIds.includes(post.userId)) {
      return errorResponse(res, 403, 'You cannot comment on this post.');
    }

    const blockExists = await Block.findOne({
      where: {
        blocker_id: post.userId,
        blocked_id: userId,
      },
    });
    if (blockExists) {
      return errorResponse(res, 403, 'You cannot comment on this post.');
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
          postId: postId, // Must be on same post
        },
      });

      if (!parentComment) {
        return errorResponse(
          res, 404,
          'Parent comment not found.'
        );
      }
    }

    // 5. PARSE/VALIDATE MENTIONS
    let validatedMentions = [];
    const clientMentions = req.body.mentions;
    if (clientMentions && Array.isArray(clientMentions) && clientMentions.length > 0) {
      const mentionedUserIds = clientMentions.map(m => m.userId || m.user_id || m.id).filter(Boolean);
      const existingUsers = await User.findAll({
        where: { id: { [Op.in]: mentionedUserIds } },
        attributes: ['id', 'username']
      });
      validatedMentions = clientMentions.filter(mention => {
        const id = mention.userId || mention.user_id || mention.id;
        return existingUsers.some(u => u.id === id);
      }).slice(0, 10).map(m => ({
        userId: m.userId || m.user_id || m.id,
        username: m.username,
        offset: m.offset || 0,
        length: m.length || 0
      }));
    }

    if (validatedMentions.length === 0 && content) {
      try {
        const { parseMentionsFromText } = require('../services/notification.service');
        const matches = content.match(/@([a-zA-Z0-9._]+)/g) || [];
        if (matches.length > 0) {
          const usernames = matches.map(m => m.slice(1).toLowerCase());
          const matchedUsers = await User.findAll({
            where: { username: { [Op.in]: usernames } },
            attributes: ['id', 'username']
          });
          validatedMentions = parseMentionsFromText(content.trim(), matchedUsers).slice(0, 10);
        }
      } catch (parseError) {
        console.error('⚠️ Warning: Failed to parse mentions from comment text:', parseError.message);
      }
    }

    // 6. CREATE COMMENT
    const comment = await Comment.create({
      postId: postId,
      userId: userId,
      content: content.trim(),
      parentCommentId: parent_comment_id || null,
      mentions: validatedMentions,
    });

    if (parentComment) {
      if (parentComment.userId !== userId) {
        notifyReply(userId, comment.id, parentComment.postId, parentComment.userId);
      }
    } else {
      notifyComment(userId, postId, comment.id);
    }

    // Send mention notifications
    if (validatedMentions.length > 0) {
      try {
        const { sendMentionNotifications } = require('../services/notification.service');
        await sendMentionNotifications({
          mentionedUserIds: validatedMentions.map(m => m.userId),
          senderId: userId,
          entityType: 'comment',
          entityId: comment.id,
          text: content,
        });
      } catch (mentionError) {
        console.error('Mention notifications error:', mentionError.message);
      }
    }

    // 6. FETCH WITH USER DATA
    const fullComment = await Comment.findByPk(comment.id, {
      include: [
        {
          model: User,
          as: 'user',
          attributes: [
            'id', 'username', 'fullName',
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

    const blockedUserIds = await getBlockedUserIds(currentUserId);

    // Check post exists
    const post = await Post.findByPk(postId);
    if (!post) {
      return errorResponse(res, 404, 'Post not found.');
    }

    // Get top-level comments only (parent_comment_id = null)
    // Pinned comments first, then newest
    const { count, rows: comments } = await Comment.findAndCountAll({
      where: {
        postId: postId,
        parentCommentId: null, // Top-level only
        is_hidden: false,
        userId: { [Op.notIn]: blockedUserIds },
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
      where: { commentId: { [Op.in]: commentIds } },
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
        parentCommentId: { [Op.in]: commentIds },
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
        userId: currentUserId,
        commentId: { [Op.in]: commentIds },
      },
      attributes: ['comment_id'],
      raw: true,
    });

    // Build lookup maps
    const likeCountMap = {};
    likeCounts.forEach((l) => {
      likeCountMap[l.commentId] = parseInt(l.count);
    });

    const replyCountMap = {};
    replyCounts.forEach((r) => {
      replyCountMap[r.parentCommentId] = parseInt(r.count);
    });

    const likedCommentIds = new Set(
      userLikes.map((l) => l.commentId)
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

    const blockedUserIds = await getBlockedUserIds(currentUserId);

    // Verify parent comment exists
    const parentComment = await Comment.findByPk(commentId);
    if (!parentComment) {
      return errorResponse(res, 404, 'Comment not found.');
    }

    const { count, rows: replies } = await Comment.findAndCountAll({
      where: {
        parentCommentId: commentId,
        is_hidden: false,
        userId: { [Op.notIn]: blockedUserIds },
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
      where: { commentId: { [Op.in]: replyIds } },
      attributes: [
        'comment_id',
        [sequelize.fn('COUNT', sequelize.col('id')), 'count'],
      ],
      group: ['comment_id'],
      raw: true,
    });

    const userLikes = await CommentLike.findAll({
      where: {
        userId: currentUserId,
        commentId: { [Op.in]: replyIds },
      },
      attributes: ['comment_id'],
      raw: true,
    });

    const likeCountMap = {};
    likeCounts.forEach((l) => {
      likeCountMap[l.commentId] = parseInt(l.count);
    });

    const likedIds = new Set(userLikes.map((l) => l.commentId));

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
    if (comment.userId !== userId) {
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
    const isCommentOwner = comment.userId === userId;
    const isPostOwner = comment.post?.userId === userId;

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
      where: { userId: userId, commentId: commentId },
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
        commentToNotify.userId,
        commentToNotify.postId
      );
    }

    const likeCount = await CommentLike.count({
      where: { commentId: commentId },
    });

    return successResponse(res, 200, 'Comment liked! ❤️', {
      commentId: commentId,
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
      where: { userId: userId, commentId: commentId },
    });

    if (deleted === 0) {
      return errorResponse(
        res, 400,
        'You have not liked this comment.'
      );
    }

    const likeCount = await CommentLike.count({
      where: { commentId: commentId },
    });

    return successResponse(res, 200, 'Comment unliked.', {
      commentId: commentId,
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
    if (comment.post?.userId !== userId) {
      return errorResponse(
        res, 403,
        'Only the post owner can pin comments.'
      );
    }

    // Unpin any currently pinned comment on this post
    await Comment.update(
      { is_pinned: false },
      { where: { postId: comment.postId, is_pinned: true } }
    );

    // Pin this comment
    await comment.update({ is_pinned: true });

    return successResponse(res, 200, 'Comment pinned! 📌', {
      commentId: commentId,
      is_pinned: true,
    });

  } catch (error) {
    console.error('❌ Pin comment error:', error);
    return errorResponse(res, 500, 'Failed to pin comment.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/comments/:id/reply
// @desc    Reply to a specific comment
// @access  Private
// ─────────────────────────────────────────────────────────────
const replyToComment = async (req, res) => {
  try {
    const { id: parentCommentId } = req.params;
    const userId = req.user.id;
    const { content } = req.body;

    if (!content || content.trim().length === 0) {
      return errorResponse(res, 400, 'Reply content is required.');
    }

    const parentComment = await Comment.findByPk(parentCommentId);
    if (!parentComment) {
      return errorResponse(res, 404, 'Parent comment not found.');
    }

    // PARSE/VALIDATE MENTIONS
    let validatedMentions = [];
    const clientMentions = req.body.mentions;
    if (clientMentions && Array.isArray(clientMentions) && clientMentions.length > 0) {
      const mentionedUserIds = clientMentions.map(m => m.userId || m.user_id || m.id).filter(Boolean);
      const existingUsers = await User.findAll({
        where: { id: { [Op.in]: mentionedUserIds } },
        attributes: ['id', 'username']
      });
      validatedMentions = clientMentions.filter(mention => {
        const id = mention.userId || mention.user_id || mention.id;
        return existingUsers.some(u => u.id === id);
      }).slice(0, 10).map(m => ({
        userId: m.userId || m.user_id || m.id,
        username: m.username,
        offset: m.offset || 0,
        length: m.length || 0
      }));
    }

    if (validatedMentions.length === 0 && content) {
      try {
        const { parseMentionsFromText } = require('../services/notification.service');
        const matches = content.match(/@([a-zA-Z0-9._]+)/g) || [];
        if (matches.length > 0) {
          const usernames = matches.map(m => m.slice(1).toLowerCase());
          const matchedUsers = await User.findAll({
            where: { username: { [Op.in]: usernames } },
            attributes: ['id', 'username']
          });
          validatedMentions = parseMentionsFromText(content.trim(), matchedUsers).slice(0, 10);
        }
      } catch (parseError) {
        console.error('⚠️ Warning: Failed to parse mentions from reply text:', parseError.message);
      }
    }

    const comment = await Comment.create({
      postId: parentComment.postId,
      userId: userId,
      content: content.trim(),
      parentCommentId: parentCommentId,
      mentions: validatedMentions,
    });

    if (parentComment.userId !== userId) {
      notifyReply(userId, comment.id, parentComment.postId, parentComment.userId);
    }
    
    // Send mention notifications
    if (validatedMentions.length > 0) {
      try {
        const { sendMentionNotifications } = require('../services/notification.service');
        await sendMentionNotifications({
          mentionedUserIds: validatedMentions.map(m => m.userId),
          senderId: userId,
          entityType: 'comment',
          entityId: comment.id,
          text: content,
        });
      } catch (mentionError) {
        console.error('Mention notifications error:', mentionError.message);
      }
    }

    const fullComment = await Comment.findByPk(comment.id, {
      include: [{ model: User, as: 'user', attributes: ['id', 'username', 'full_name', 'profile_pic_url', 'is_verified'] }],
    });

    const commentData = fullComment.toJSON();
    commentData.like_count = 0;
    commentData.reply_count = 0;
    commentData.is_liked = false;

    return successResponse(res, 201, 'Reply added successfully!', {
      reply: formatComment(commentData, userId),
    });
  } catch (error) {
    console.error('❌ Reply comment error:', error);
    return errorResponse(res, 500, 'Failed to add reply.');
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
  replyToComment,
};
