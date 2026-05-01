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
    post_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'posts', key: 'id' },
      onDelete: 'CASCADE',
    },

    // Who wrote this comment
    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },

    // NULL = top-level comment
    // Has value = reply to another comment
    parent_comment_id: {
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
    ],
  }
);

module.exports = Comment;