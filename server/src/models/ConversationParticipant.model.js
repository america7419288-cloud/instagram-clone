// server/src/models/ConversationParticipant.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const ConversationParticipant = sequelize.define(
  'ConversationParticipant',
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

    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Role in group chat
    role: {
      type: DataTypes.ENUM('admin', 'member'),
      defaultValue: 'member',
      allowNull: false,
    },

    // Nickname inside this conversation
    nickname: {
      type: DataTypes.STRING(50),
      allowNull: true,
    },

    // When user last read this conversation
    // Used to calculate unread count
    last_read_at: {
      type: DataTypes.DATE,
      allowNull: true,
    },

    // Has user muted this conversation?
    is_muted: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },

    // When user left group (NULL = still in group)
    left_at: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    tableName: 'conversation_participants',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['conversation_id'] },
      { fields: ['user_id'] },
      {
        // Each user can only be in a conversation once
        unique: true,
        fields: ['conversation_id', 'user_id'],
        name: 'unique_conversation_participant',
      },
    ],
  }
);

module.exports = ConversationParticipant;