// server/src/models/Conversation.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Conversation = sequelize.define(
  'Conversation',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    // Group chat name (NULL for 1-on-1 DMs)
    name: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },

    // Group chat avatar (NULL for DMs)
    avatar_url: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },

    // Is this a group chat or DM?
    is_group: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },

    // Who created this conversation
    created_by: {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'SET NULL',
    },

    // Snapshot of last message (for inbox preview)
    last_message: {
      type: DataTypes.TEXT,
      allowNull: true,
    },

    // When last message was sent
    last_message_at: {
      type: DataTypes.DATE,
      allowNull: true,
    },

    // Who sent the last message
    last_message_sender_id: {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'SET NULL',
    },

    // Duration in seconds for disappearing messages
    disappearing_duration: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },

    // Group Settings
    only_admins_can_send: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    only_admins_can_add_members: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    only_admins_can_edit_info: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    approval_required: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    invite_link: {
      type: DataTypes.STRING(20),
      allowNull: true,
    },
    is_invite_link_active: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    invite_link_expiry: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    tableName: 'conversations',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['created_by'] },
      { fields: ['last_message_at'] },
      { fields: ['is_group'] },
    ],
  }
);

module.exports = Conversation;