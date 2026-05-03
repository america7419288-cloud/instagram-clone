// server/src/models/Notification.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Notification = sequelize.define(
  'Notification',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    // Who receives this notification
    recipientId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Who triggered this notification
    // NULL for system notifications
    senderId: {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // What type of notification
    type: {
      type: DataTypes.ENUM(
        'like',            // Liked your post
        'comment',         // Commented on your post
        'reply',           // Replied to your comment
        'follow',          // Started following you
        'follow_request',  // Sent follow request (private acct)
        'follow_accept',   // Accepted your follow request
        'mention_post',    // Mentioned you in post caption
        'mention_comment', // Mentioned you in comment
        'comment_like',    // Liked your comment
        'story_view',      // Viewed your story
        'reel_like',       // Liked your reel
        'reel_comment',    // Commented on your reel
        'system'           // System message
      ),
      allowNull: false,
    },

    // Reference to what triggered the notification
    // All optional - depends on type
    postId: {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'posts',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    commentId: {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'comments',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    storyId: {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'stories',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    reelId: {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'reels',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Custom message (for system notifications)
    message: {
      type: DataTypes.TEXT,
      allowNull: true,
    },

    // Has user seen this notification?
    isRead: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },
  },
  {
    tableName: 'notifications',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['recipient_id'] },
      { fields: ['sender_id'] },
      { fields: ['is_read'] },
      { fields: ['type'] },
      { fields: ['created_at'] },
      // Composite for common query
      {
        fields: ['recipient_id', 'is_read'],
        name: 'idx_notifications_recipient_read',
      },
    ],
  }
);

module.exports = Notification;