// server/src/models/ContentInteraction.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const ContentInteraction = sequelize.define(
  'ContentInteraction',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },

    contentId: {
      type: DataTypes.UUID,
      allowNull: false,
    },

    contentType: {
      type: DataTypes.STRING(50),
      allowNull: false, // 'post', 'reel', 'story', 'comment', 'user', 'hashtag'
    },

    authorId: {
      type: DataTypes.UUID,
      allowNull: true,
      references: { model: 'users', key: 'id' },
      onDelete: 'SET NULL',
    },

    action: {
      type: DataTypes.STRING(50),
      allowNull: false, // like, comment, share, save, profile_visit, hashtag_click, follow, video_watch_25/50/75/100, carousel_swipe, link_click, story_reply, story_react, not_interested, hide, report, unfollow, scroll_past
    },

    dwellTime: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0, // in milliseconds
    },

    source: {
      type: DataTypes.STRING(50),
      allowNull: false,
      defaultValue: 'feed', // 'feed', 'explore', 'reels', 'stories', 'profile', 'hashtag', 'search', 'dm'
    },

    sessionId: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },

    contentCategories: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },

    contentHashtags: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },
  },
  {
    tableName: 'content_interactions',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['user_id', 'created_at'] },
      { fields: ['content_id', 'action'] },
      { fields: ['user_id', 'content_type'] },
      { fields: ['author_id', 'action'] },
    ],
  }
);

module.exports = ContentInteraction;
