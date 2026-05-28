// server/src/models/Post.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Post = sequelize.define(
  'Post',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },

    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      field: 'user_id',
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    caption: {
      type: DataTypes.TEXT,
      allowNull: true,
    },

    location: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },

    // ─── Denormalized counts (fast reads) ─────────────
    // Updated via increment/decrement in controllers
    likesCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      field: 'like_count',
    },

    commentsCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      field: 'comment_count',
    },

    isArchived: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
      field: 'is_archived',
    },

    // ─── Music Metadata ──────────────────────────────
    musicId: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'music_id',
    },
    musicTitle: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'music_title',
    },
    musicArtist: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'music_artist',
    },
    musicStartTime: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'music_start_time',
    },
    musicDuration: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'music_duration',
    },
    mentions: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },

    isPinned: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
      field: 'is_pinned',
    },

    hideLikesCount: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
      field: 'hide_likes_count',
    },

    commentsDisabled: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
      field: 'comments_disabled',
    },

    audience: {
      type: DataTypes.STRING(50),
      allowNull: false,
      defaultValue: 'everyone',
      field: 'audience',
    },

    categories: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },

    sharesCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      field: 'shares_count',
    },

    viewsCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      field: 'views_count',
    },
  },
  {
    tableName: 'posts',
    underscored: true,
    timestamps: true,
    indexes: [
      { fields: ['user_id'] },
      { fields: ['created_at'] },
    ],
  }
);

module.exports = Post;