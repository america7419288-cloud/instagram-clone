// server/src/models/Message.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Message = sequelize.define(
  'Message',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    conversation_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'conversations',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    sender_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Text content (NULL for media-only messages)
    content: {
      type: DataTypes.TEXT,
      allowNull: true,
    },

    // Media URL (image/video/audio)
    media_url: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },

    // What type of message is this?
    message_type: {
      type: DataTypes.ENUM(
        'text',        // Regular text
        'image',       // Image
        'video',       // Video
        'audio',       // Voice note
        'post_share',  // Shared a post (legacy)
        'story_share', // Shared a story (legacy)
        'post',        // Shared a post
        'reel',        // Shared a reel
        'story',       // Shared a story
        'profile',     // Shared a profile
        'like',        // Just sent ❤️
        'gif'          // GIF
      ),
      defaultValue: 'text',
      allowNull: false,
    },

    // If sharing content, store the ID (Post, Reel, or Story)
    shared_post_id: {
      type: DataTypes.UUID,
      allowNull: true,
      // No strict references here to allow polymorphic sharing
    },

    // Reply to another message in same conversation
    reply_to_message_id: {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'messages',
        key: 'id',
      },
      onDelete: 'SET NULL',
    },

    // "Unsend" - message deleted but record kept
    // So other users see "This message was unsent"
    is_deleted: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },

    // When message was deleted
    deleted_at: {
      type: DataTypes.DATE,
      allowNull: true,
    },

    // Message editing status
    is_edited: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },

    // When message was last edited
    edited_at: {
      type: DataTypes.DATE,
      allowNull: true,
    },

    // When disappearing message expires
    expires_at: {
      type: DataTypes.DATE,
      allowNull: true,
    },

    // Emoji reactions: { "❤️": ["userId1", "userId2"], "😂": ["userId3"] }
    reactions: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {},
    },
    mentions: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },
  },
  {
    tableName: 'messages',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['conversation_id'] },
      { fields: ['sender_id'] },
      // For ordering messages in a conversation
      {
        fields: ['conversation_id', 'created_at'],
        name: 'idx_messages_conversation_time',
      },
    ],
  }
);

module.exports = Message;