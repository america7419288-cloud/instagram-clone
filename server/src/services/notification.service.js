// server/src/services/notification.service.js

const { v4: uuidv4 } = require('uuid');
const { Notification, Post, PostMedia, User } = require('../models');
const { sendPushNotification } = require('./push.service');

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
  postId = null,
  commentId = null,
  storyId = null,
  reelId = null,
  message = null,
}) => {
  try {
    // ─── Never notify yourself ─────────────────────────
    if (recipientId === senderId) return null;

    // ─── Create DB notification ────────────────────────
    const notification = await Notification.create({
      id: uuidv4(),
      recipientId,
      senderId,
      type,
      postId,
      commentId,
      storyId,
      reelId,
      message,
      isRead: false,
    });

    // ─── Fetch sender + recipient for push ────────────
    const [sender, recipient] = await Promise.all([
      User.findByPk(senderId, {
        attributes: ['id', 'username', 'profile_pic_url', 'is_verified'],
      }),
      User.findByPk(recipientId, {
        attributes: ['id', 'fcmToken'],
      }),
    ]);

    // ─── Emit Socket Notification ─────────────────────
    try {
      const { emitToUser, getIO } = require('./socket.service');
      const io = getIO();
      if (io && sender) {
        emitToUser(io, recipientId, 'new-notification', {
          id: notification.id,
          recipientId,
          senderId,
          type,
          postId,
          commentId,
          storyId,
          reelId,
          message,
          isRead: false,
          createdAt: notification.createdAt,
          sender: {
            id: sender.id,
            username: sender.username,
            profile_pic_url: sender.profile_pic_url,
            is_verified: sender.is_verified,
          }
        });
      }
    } catch (socketError) {
      console.warn('⚠️ Warning: Socket emit notification failed:', socketError.message);
    }

    // ─── NOTIFICATIONS ALGORITHM: Alert fatigue suppression ──
    const MINOR_TYPES = ['like', 'comment_like', 'reel_like', 'story_react', 'follow', 'comment'];
    
    if (MINOR_TYPES.includes(type)) {
      try {
        const { UserInterestProfile } = require('../models');
        const recipientProfile = await UserInterestProfile.findOne({
          where: { userId: recipientId }
        });

        if (recipientProfile) {
          const hour = new Date().getHours();
          const activeHours = recipientProfile.activeHours || {};
          const hourActivity = activeHours[hour] || 0;
          
          const maxActivity = Math.max(...Object.values(activeHours), 1);
          const isLowActivityHour = (hourActivity / maxActivity) < 0.15 && maxActivity > 5;

          const recentAuthors = recipientProfile.recentAuthors || [];
          const authorRelation = recentAuthors.find(a => a.authorId === senderId);
          const relationScore = authorRelation ? authorRelation.score : 0;

          if (isLowActivityHour || relationScore < 5) {
            console.log(`🔕 Suppressed push notification type: ${type} to user ${recipientId} due to alert fatigue algorithms`);
            return notification; // Silent in-app delivery only, no push alert
          }
        }
      } catch (fatigueError) {
        console.warn('⚠️ Alert fatigue suppression check failed:', fatigueError.message);
      }
    }

    // ─── Send push notification ────────────────────────
    if (sender && recipient?.fcmToken) {
      const pushResult = await sendPushNotification({
        fcmToken: recipient.fcmToken,
        type,
        senderUsername: sender.username,
        extra: {
          postId: postId || '',
          commentId: commentId || '',
          storyId: storyId || '',
          senderUsername: sender.username,
        },
      });

      // ─── Clear invalid token from DB ────────────────
      if (pushResult === 'invalid_token') {
        await User.update(
          { fcmToken: null },
          { where: { id: recipientId } }
        );
        console.log(`🗑️ Cleared invalid FCM token for user ${recipientId}`);
      }
    }

    return notification;
  } catch (error) {
    // ─── Non-fatal: log but don't throw ───────────────
    console.error('❌ createNotification error:', error.message);
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
      recipientId: post.userId,
      senderId,
      type: 'like',
      postId,
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
      recipientId: post.userId,
      senderId,
      type: 'comment',
      postId,
      commentId,
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
      postId,
      commentId,
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
      postId,
      commentId,
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
      postId,
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
      postId,
      commentId,
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

// ─────────────────────────────────────────────────────
// CREATE MESSAGE NOTIFICATION
// Special handler for DM push notifications
// ─────────────────────────────────────────────────────
const createMessageNotification = async ({
  recipientId,
  senderId,
  conversationId,
  messageText,
}) => {
  try {
    if (recipientId === senderId) return;

    // ─── Fetch sender + recipient ──────────────────────
    const [sender, recipient] = await Promise.all([
      User.findByPk(senderId, {
        attributes: ['id', 'username'],
      }),
      User.findByPk(recipientId, {
        attributes: ['id', 'fcmToken'],
      }),
    ]);

    if (!sender || !recipient?.fcmToken) return;

    // ─── Send push (no DB notification for messages) ──
    const pushResult = await sendPushNotification({
      fcmToken: recipient.fcmToken,
      type: 'message',
      senderUsername: sender.username,
      extra: {
        messageText,
        conversationId,
        senderUsername: sender.username,
      },
    });

    // ─── Clear invalid token ───────────────────────────
    if (pushResult === 'invalid_token') {
      await User.update(
        { fcmToken: null },
        { where: { id: recipientId } }
      );
    }
  } catch (error) {
    console.error('❌ createMessageNotification error:', error.message);
  }
};

const sendMentionNotifications = async ({
  mentionedUserIds,
  senderId,
  entityType,    // 'post' | 'message' | 'comment' | 'story' | 'reel' | 'community_post'
  entityId,
  text,          // preview text
}) => {
  try {
    if (!mentionedUserIds || mentionedUserIds.length === 0) return;

    const uniqueIds = [...new Set(
      mentionedUserIds.map(id => id.toString())
    )].filter(id => id !== senderId.toString());

    for (const userId of uniqueIds) {
      let type = `mention_${entityType}`;
      if (entityType === 'post' || entityType === 'reel') {
        type = 'mention_caption';
      } else if (entityType === 'community_post') {
        type = 'mention_message';
      }

      await createNotification({
        recipientId: userId,
        senderId,
        type,
        postId: (entityType === 'post' || entityType === 'comment' || entityType === 'community_post') ? entityId : null,
        commentId: entityType === 'comment' ? entityId : null,
        reelId: entityType === 'reel' ? entityId : null,
        storyId: entityType === 'story' ? entityId : null,
        message: text?.substring(0, 100) || '',
      });
    }
  } catch (error) {
    console.error('❌ sendMentionNotifications error:', error.message);
  }
};

const parseMentionsFromText = (text, knownUsers) => {
  // knownUsers: [{ id, username }]
  const mentions = [];
  const mentionRegex = /@([a-zA-Z0-9._]+)/g;
  let match;

  if (!text) return mentions;

  while ((match = mentionRegex.exec(text)) !== null) {
    const username = match[1].toLowerCase();
    const user = knownUsers.find(
      u => u.username.toLowerCase() === username
    );

    if (user) {
      mentions.push({
        userId: user.id,
        username: user.username,
        offset: match.index,
        length: match[0].length, // includes '@'
      });
    }
  }

  return mentions;
};

module.exports = {
  createNotification,
  createMessageNotification,
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
  sendMentionNotifications,
  parseMentionsFromText,
};
