// server/src/services/notification.service.js

const { Notification, Post, PostMedia, User } = require('../models');

// ─── HELPER: Get post thumbnail ────────────────────────────
const getPostThumbnail = async (postId) => {
  if (!postId) return null;
  try {
    const media = await PostMedia.findOne({
      where: { postId },
      order: [['order', 'ASC']],
      attributes: ['thumbnailUrl', 'url'],
    });
    return media?.thumbnailUrl || media?.url || null;
  } catch (e) {
    return null;
  }
};

// ─── CREATE NOTIFICATION ───────────────────────────────────
// Core function - all others call this
const createNotification = async ({
  recipientId,
  senderId,
  type,
  referencePostId = null,
  referenceCommentId = null,
  referenceStoryId = null,
  message = null,
}) => {
  try {
    // Don't notify yourself
    if (recipientId === senderId) return null;

    // Check if exact same notification already exists recently
    // (prevent duplicate notifications)
    const recentDuplicate = await Notification.findOne({
      where: {
        recipient_id: recipientId,
        sender_id: senderId,
        type,
        ...(referencePostId && { reference_post_id: referencePostId }),
        ...(referenceCommentId && {
          reference_comment_id: referenceCommentId,
        }),
      },
    });

    if (recentDuplicate) {
      // Update timestamp instead of creating duplicate
      await recentDuplicate.update({ is_read: false });
      return recentDuplicate;
    }

    const notification = await Notification.create({
      recipient_id: recipientId,
      sender_id: senderId,
      type,
      reference_post_id: referencePostId,
      reference_comment_id: referenceCommentId,
      reference_story_id: referenceStoryId,
      message,
      is_read: false,
    });

    return notification;
  } catch (error) {
    // Notification failures should never break main action
    console.error('❌ Create notification error:', error.message);
    return null;
  }
};

// ─── NOTIFY: LIKE ──────────────────────────────────────────
// When someone likes your post
const notifyLike = async (senderId, postId) => {
  try {
    const post = await Post.findByPk(postId);
    if (!post) return;

    return await createNotification({
      recipientId: post.user_id,
      senderId,
      type: 'like',
      referencePostId: postId,
    });
  } catch (error) {
    console.error('Notify like error:', error.message);
  }
};

// ─── NOTIFY: COMMENT ───────────────────────────────────────
// When someone comments on your post
const notifyComment = async (senderId, postId, commentId) => {
  try {
    const post = await Post.findByPk(postId);
    if (!post) return;

    return await createNotification({
      recipientId: post.user_id,
      senderId,
      type: 'comment',
      referencePostId: postId,
      referenceCommentId: commentId,
    });
  } catch (error) {
    console.error('Notify comment error:', error.message);
  }
};

// ─── NOTIFY: REPLY ─────────────────────────────────────────
// When someone replies to your comment
const notifyReply = async (senderId, commentId, postId, originalCommentUserId) => {
  try {
    return await createNotification({
      recipientId: originalCommentUserId,
      senderId,
      type: 'reply',
      referencePostId: postId,
      referenceCommentId: commentId,
    });
  } catch (error) {
    console.error('Notify reply error:', error.message);
  }
};

// ─── NOTIFY: FOLLOW ────────────────────────────────────────
// When someone follows you (public account)
const notifyFollow = async (senderId, recipientId) => {
  try {
    return await createNotification({
      recipientId,
      senderId,
      type: 'follow',
    });
  } catch (error) {
    console.error('Notify follow error:', error.message);
  }
};

// ─── NOTIFY: FOLLOW REQUEST ────────────────────────────────
// When someone requests to follow your private account
const notifyFollowRequest = async (senderId, recipientId) => {
  try {
    return await createNotification({
      recipientId,
      senderId,
      type: 'follow_request',
    });
  } catch (error) {
    console.error('Notify follow request error:', error.message);
  }
};

// ─── NOTIFY: FOLLOW ACCEPTED ───────────────────────────────
// When a private account accepts your follow request
const notifyFollowAccepted = async (senderId, recipientId) => {
  try {
    return await createNotification({
      recipientId,
      senderId,
      type: 'follow_accept',
    });
  } catch (error) {
    console.error('Notify follow accept error:', error.message);
  }
};

// ─── NOTIFY: COMMENT LIKE ──────────────────────────────────
// When someone likes your comment
const notifyCommentLike = async (
  senderId,
  commentId,
  commentOwnerId,
  postId
) => {
  try {
    return await createNotification({
      recipientId: commentOwnerId,
      senderId,
      type: 'comment_like',
      referencePostId: postId,
      referenceCommentId: commentId,
    });
  } catch (error) {
    console.error('Notify comment like error:', error.message);
  }
};

// ─── NOTIFY: MENTION IN CAPTION ────────────────────────────
// When someone @mentions you in a post caption
const notifyMentionInPost = async (
  senderId,
  recipientId,
  postId
) => {
  try {
    return await createNotification({
      recipientId,
      senderId,
      type: 'mention_post',
      referencePostId: postId,
    });
  } catch (error) {
    console.error('Notify mention post error:', error.message);
  }
};

// ─── NOTIFY: MENTION IN COMMENT ────────────────────────────
// When someone @mentions you in a comment
const notifyMentionInComment = async (
  senderId,
  recipientId,
  postId,
  commentId
) => {
  try {
    return await createNotification({
      recipientId,
      senderId,
      type: 'mention_comment',
      referencePostId: postId,
      referenceCommentId: commentId,
    });
  } catch (error) {
    console.error('Notify mention comment error:', error.message);
  }
};

// ─── EXTRACT MENTIONS FROM TEXT ────────────────────────────
// Finds @username patterns in text
const extractMentions = (text) => {
  if (!text) return [];
  const regex = /@([a-zA-Z0-9._]+)/g;
  const matches = text.match(regex) || [];
  return [...new Set(matches.map((m) => m.slice(1).toLowerCase()))];
};

// ─── PROCESS MENTIONS ──────────────────────────────────────
// Find mentioned users and create notifications for them
const processMentions = async (
  text,
  senderId,
  postId,
  commentId = null
) => {
  try {
    const mentions = extractMentions(text);
    if (mentions.length === 0) return;

    for (const username of mentions) {
      const mentionedUser = await User.findOne({
        where: { username: username.toLowerCase() },
        attributes: ['id'],
      });

      if (!mentionedUser || mentionedUser.id === senderId) continue;

      if (commentId) {
        await notifyMentionInComment(
          senderId,
          mentionedUser.id,
          postId,
          commentId
        );
      } else {
        await notifyMentionInPost(senderId, mentionedUser.id, postId);
      }
    }
  } catch (error) {
    console.error('Process mentions error:', error.message);
  }
};

module.exports = {
  createNotification,
  notifyLike,
  notifyComment,
  notifyReply,
  notifyFollow,
  notifyFollowRequest,
  notifyFollowAccepted,
  notifyCommentLike,
  notifyMentionInPost,
  notifyMentionInComment,
  processMentions,
};