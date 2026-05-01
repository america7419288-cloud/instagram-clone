// server/src/models/PostMedia.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const PostMedia = sequelize.define(
  'PostMedia',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    post_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'posts',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Full quality URL (stored on Cloudinary)
    media_url: {
      type: DataTypes.STRING(500),
      allowNull: false,
    },

    // For videos: preview image
    thumbnail_url: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },

    // Resized versions for performance
    small_url: {
      type: DataTypes.STRING(500), // 300x300 for grid
      allowNull: true,
    },

    medium_url: {
      type: DataTypes.STRING(500), // 600px for feed
      allowNull: true,
    },

    // 'image' or 'video'
    media_type: {
      type: DataTypes.ENUM('image', 'video'),
      allowNull: false,
    },

    // Cloudinary public_id (needed for deletion)
    cloudinary_public_id: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },

    // Position in carousel (0 = first)
    display_order: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      allowNull: false,
    },

    // Original dimensions
    width: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },

    height: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },

    // For videos
    duration: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
  },
  {
    tableName: 'post_media',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['post_id'] },
      { fields: ['display_order'] },
    ],
  }
);

module.exports = PostMedia;