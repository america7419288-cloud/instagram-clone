// server/src/models/Note.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Note = sequelize.define(
  'Note',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    // Author of the note
    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Note content (max 60 characters)
    text: {
      type: DataTypes.STRING(60),
      allowNull: false,
      validate: {
        notEmpty: { msg: 'Note text cannot be empty' },
        len: {
          args: [1, 60],
          msg: 'Note must be between 1 and 60 characters',
        },
      },
    },

    // Note audience: 'followers' or 'close_friends'
    audience: {
      type: DataTypes.ENUM('followers', 'close_friends'),
      defaultValue: 'followers',
      allowNull: false,
    },

    // Expiry date (defaults to 24 hours from creation)
    expires_at: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: () => {
        const now = new Date();
        now.setHours(now.getHours() + 24);
        return now;
      },
    },

    // Note Type: 'text' | 'music' | 'gif'
    note_type: {
      type: DataTypes.STRING(50),
      defaultValue: 'text',
      allowNull: false,
    },

    // Music Share attributes
    music_track_id: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    music_track_name: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    music_artist_name: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    music_album_art: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    music_preview_url: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    music_duration: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    music_platform: {
      type: DataTypes.STRING(50),
      defaultValue: 'spotify',
      allowNull: false,
    },

    // GIF share attributes
    gif_id: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    gif_url: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    gif_preview_url: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    gif_title: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    gif_width: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    gif_height: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    gif_source: {
      type: DataTypes.STRING(50),
      defaultValue: 'giphy',
      allowNull: false,
    },
  },
  {
    tableName: 'notes',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['user_id'] },
      { fields: ['expires_at'] },
      { fields: ['created_at'] },
    ],
  }
);

module.exports = Note;
