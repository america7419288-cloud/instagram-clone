// server/src/controllers/notification.controller.js

const { Notification, User, Post, PostMedia, Comment, Block } =
  require('../models');
const { getBlockedUserIds } = require('../utils/block.utils');
const {
  successResponse,
  errorResponse,
  paginatedResponse,
} = require('../utils/response.utils');
const { Op } = require('sequelize');

// ─── HELPER: Format notification ───────────────────────────
const formatNotification = (notification) => {
  const n = notification.toJSON ? notification.toJSON() : notification;

  // Get post thumbnail from eager-loaded post (no additional query)
  let postThumbnail = null;
  if (n.post && n.post.media && n.post.media.length > 0) {
    const firstMedia = n.post.media[0];
    postThumbnail = firstMedia.thumbnail_url || firstMedia.url;
  }

  // Build human-readable message based on type
  const senderUsername = n.sender?.username || 'Someone';
  const messageMap = {
    like: `${senderUsername} liked your photo.`,
    comment: `${senderUsername} commented on your photo.`,
    reply: `${senderUsername} replied to your comment.`,
    follow: `${senderUsername} started following you.`,
    follow_request: `${senderUsername} requested to follow you.`,
    follow_accept: `${senderUsername} accepted your follow request.`,
    mention_post: `${senderUsername} mentioned you in a photo.`,
    mention_comment: `${senderUsername} mentioned you in a comment.`,
    comment_like: `${senderUsername} liked your comment.`,
    story_view: `${senderUsername} viewed your story.`,
    reel_like: `${senderUsername} liked your reel.`,
    reel_comment: `${senderUsername} commented on your reel.`,
    system: n.message || 'System notification.',
  };

  return {
    id: n.id,
    type: n.type,
    is_read: n.isRead,
    message: messageMap[n.type] || n.message,
    created_at: n.created_at || n.createdAt,

    // Who sent the notification
        sender: n.sender
      ? {
          id: n.sender.id,
          username: n.sender.username,
          full_name: n.sender.fullName || n.sender.full_name,
          profile_pic_url: n.sender.profile_pic_url,
          is_verified: n.sender.is_verified,
        }
      : null,

    // References (for deep linking)
    reference_post_id: n.postId,
    reference_comment_id: n.commentId,
    reference_story_id: n.storyId,
    reference_reel_id: n.reelId,
    post_thumbnail: postThumbnail,
  };
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/notifications/
// @desc    Get all notifications for current user
// @access  Private
// ─────────────────────────────────────────────────────────────
const getNotifications = async (req, res) => {
  try {
    const userId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const type = req.query.type || null; // Filter by type

    const blockedUserIds = await getBlockedUserIds(userId);

    const whereClause = {
      recipientId: userId,
      ...(blockedUserIds.length > 0 && { senderId: { [Op.notIn]: blockedUserIds } }),
      ...(type && { type }),
    };

    const { count, rows: notifications } =
      await Notification.findAndCountAll({
        where: whereClause,
        include: [
          {
            model: User,
            as: 'sender',
            attributes: [
              'id', 'username', 'fullName',
              'profile_pic_url', 'is_verified',
            ],
          },
          {
            model: Post,
            as: 'post',
            required: false,
            attributes: ['id'],
            include: [{
              model: PostMedia,
              as: 'media',
              attributes: ['thumbnail_url', 'url'],
              order: [['order', 'ASC']],
              limit: 1,
              separate: true,
            }],
          },
        ],
        order: [['created_at', 'DESC']],
        limit,
        offset,
      });

    // Format all notifications (no additional queries needed now)
    const formattedNotifications = notifications.map(formatNotification);

    return paginatedResponse(
      res,
      'Notifications fetched successfully',
      formattedNotifications,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get notifications error:', error);
    return errorResponse(res, 500, 'Failed to fetch notifications.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/notifications/unread-count
// @desc    Get count of unread notifications (for badge)
// @access  Private
// ─────────────────────────────────────────────────────────────
const getUnreadCount = async (req, res) => {
  try {
    const userId = req.user.id;

    const count = await Notification.count({
      where: {
        recipientId: userId,
        isRead: false,
      },
    });

    return successResponse(
      res,
      200,
      'Unread count fetched',
      { unread_count: count }
    );

  } catch (error) {
    console.error('❌ Get unread count error:', error);
    return errorResponse(res, 500, 'Failed to get unread count.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   PUT /api/v1/notifications/read-all
// @desc    Mark ALL notifications as read
// @access  Private
// ─────────────────────────────────────────────────────────────
const markAllAsRead = async (req, res) => {
  try {
    const userId = req.user.id;

    const [updatedCount] = await Notification.update(
      { isRead: true },
      {
        where: {
          recipientId: userId,
          isRead: false,
        },
      }
    );

    return successResponse(
      res,
      200,
      'All notifications marked as read.',
      { updated_count: updatedCount }
    );

  } catch (error) {
    console.error('❌ Mark all read error:', error);
    return errorResponse(res, 500, 'Failed to mark notifications as read.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   PUT /api/v1/notifications/:id/read
// @desc    Mark ONE notification as read
// @access  Private
// ─────────────────────────────────────────────────────────────
const markAsRead = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const notification = await Notification.findOne({
      where: {
        id,
        recipientId: userId, // Security: only own notifications
      },
    });

    if (!notification) {
      return errorResponse(res, 404, 'Notification not found.');
    }

    await notification.update({ isRead: true });

    return successResponse(
      res,
      200,
      'Notification marked as read.',
      { id, isRead: true }
    );

  } catch (error) {
    console.error('❌ Mark as read error:', error);
    return errorResponse(res, 500, 'Failed to mark notification as read.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/notifications/:id
// @desc    Delete ONE notification
// @access  Private
// ─────────────────────────────────────────────────────────────
const deleteNotification = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const deleted = await Notification.destroy({
      where: {
        id,
        recipientId: userId,
      },
    });

    if (deleted === 0) {
      return errorResponse(res, 404, 'Notification not found.');
    }

    return successResponse(
      res,
      200,
      'Notification deleted.',
      { id }
    );

  } catch (error) {
    console.error('❌ Delete notification error:', error);
    return errorResponse(res, 500, 'Failed to delete notification.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/notifications/
// @desc    Delete ALL notifications for current user
// @access  Private
// ─────────────────────────────────────────────────────────────
const deleteAllNotifications = async (req, res) => {
  try {
    const userId = req.user.id;

    const deletedCount = await Notification.destroy({
      where: { recipientId: userId },
    });

    return successResponse(
      res,
      200,
      `${deletedCount} notifications cleared.`,
      { deleted_count: deletedCount }
    );

  } catch (error) {
    console.error('❌ Delete all notifications error:', error);
    return errorResponse(res, 500, 'Failed to clear notifications.');
  }
};

module.exports = {
  getNotifications,
  getUnreadCount,
  markAllAsRead,
  markAsRead,
  deleteNotification,
  deleteAllNotifications,
};
