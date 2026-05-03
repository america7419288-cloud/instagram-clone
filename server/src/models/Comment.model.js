// server/src/models/Comment.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Comment = sequelize.define(
  'Comment',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    // Which post this comment belongs to
    postId: {
      type: DataTypes.UUID,
      allowNull: true, // Allow NULL for reel comments
      references: { model: 'posts', key: 'id' },
      onDelete: 'CASCADE',
    },

    // ─── NEW: Reel comment support ────────────────────
    reelId: {
      type: DataTypes.UUID,
      allowNull: true,   // Allow NULL for post comments
      references: {
        model: 'reels',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Who wrote this comment
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },

    // NULL = top-level comment
    // Has value = reply to another comment
    parentCommentId: {
      type: DataTypes.UUID,
      allowNull: true,
      references: { model: 'comments', key: 'id' },
      onDelete: 'CASCADE',
    },

    // The actual comment text
    content: {
      type: DataTypes.TEXT,
      allowNull: false,
      validate: {
        notEmpty: { msg: 'Comment cannot be empty' },
        len: {
          args: [1, 2200],
          msg: 'Comment cannot exceed 2200 characters',
        },
      },
    },

    likesCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    repliesCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    // Post owner can pin one comment
    is_pinned: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },

    // Post owner can hide comments
    is_hidden: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
  },
  {
    tableName: 'comments',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['post_id'] },
      { fields: ['user_id'] },
      { fields: ['parent_comment_id'] },
      { fields: ['is_pinned'] },
      { fields: ['reel_id'] },
    ],
  }
);

module.exports = Comment;