// server/src/models/CommunityPost.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const CommunityPost = sequelize.define(
  'CommunityPost',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },
    community_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'communities',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },
    channel_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'community_channels',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },
    author_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },
    content: {
      type: DataTypes.TEXT,
      allowNull: true,
      defaultValue: '',
    },
    media_urls: {
      type: DataTypes.JSONB,
      defaultValue: [],
      allowNull: false,
    },
    type: {
      type: DataTypes.ENUM('text', 'media', 'poll', 'event', 'announcement'),
      defaultValue: 'text',
      allowNull: false,
    },
    poll: {
      type: DataTypes.JSONB,
      allowNull: true,
    },
    event: {
      type: DataTypes.JSONB,
      allowNull: true,
    },
    likes: {
      type: DataTypes.JSONB,
      defaultValue: [],
      allowNull: false,
    },
    comment_count: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      allowNull: false,
    },
    like_count: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      allowNull: false,
    },
    is_pinned: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },
    is_announcement: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM('published', 'pending', 'rejected'),
      defaultValue: 'published',
      allowNull: false,
    },
    rejected_reason: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    mentions: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },
  },
  {
    tableName: 'community_posts',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['community_id'] },
      { fields: ['channel_id'] },
      { fields: ['author_id'] },
      { fields: ['created_at'] },
    ],
  }
);

module.exports = CommunityPost;
