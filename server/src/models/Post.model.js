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
      allowNull: false,
    },

    // Who created this post
    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE', // If user deleted → delete their posts
    },

    // Post text content
    caption: {
      type: DataTypes.TEXT,
      allowNull: true,
      validate: {
        len: {
          args: [0, 2200],
          msg: 'Caption cannot exceed 2200 characters',
        },
      },
    },

    // Where the photo was taken
    location: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },

    // Archived posts hidden from profile
    // but not deleted
    is_archived: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },

    // Comments disabled for this post
    comments_disabled: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },

    // Accessibility alt text for images
    alt_text: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
  },
  {
    tableName: 'posts',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['user_id'] },
      { fields: ['created_at'] },
      { fields: ['is_archived'] },
    ],
  }
);

module.exports = Post;