// server/src/models/Story.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Story = sequelize.define(
  'Story',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    // Who posted this story
    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Story media
    media_url: {
      type: DataTypes.STRING(500),
      allowNull: false,
      validate: {
        notEmpty: { msg: 'Media URL is required' },
      },
    },

    // For video stories: preview image
    thumbnail_url: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },

    // 'image' or 'video'
    media_type: {
      type: DataTypes.ENUM('image', 'video'),
      allowNull: false,
      defaultValue: 'image',
    },

    // Cloudinary ID for deletion
    cloudinary_public_id: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },

    // Text overlay on story
    caption: {
      type: DataTypes.STRING(200),
      allowNull: true,
    },

    // Link (swipe up)
    link: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },

    // Who can see this story
    // 'followers' = all followers
    // 'close_friends' = close friends list only
    audience: {
      type: DataTypes.ENUM('followers', 'close_friends'),
      defaultValue: 'followers',
      allowNull: false,
    },

    // Story auto-expires after 24 hours
    expires_at: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: () => {
        const now = new Date();
        now.setHours(now.getHours() + 24);
        return now;
      },
    },

    // Story dimensions (for layout)
    width: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },

    height: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },

    // Video duration in seconds
    duration: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },

    // ─── Music Integration ──────────────────────────────
    music_id: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    music_title: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    music_artist: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    music_thumbnail: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    music_start_time: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: 0,
    },
    music_duration: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: 15,
    },
  },
  {
    tableName: 'stories',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['user_id'] },
      { fields: ['expires_at'] },  // For cleanup queries
      { fields: ['audience'] },
      { fields: ['created_at'] },
    ],
  }
);

module.exports = Story;