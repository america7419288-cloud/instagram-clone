// server/src/models/CommunityChannel.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const CommunityChannel = sequelize.define(
  'CommunityChannel',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },
    community_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'communities',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },
    name: {
      type: DataTypes.STRING(50),
      allowNull: false,
    },
    description: {
      type: DataTypes.STRING(200),
      allowNull: true,
    },
    type: {
      type: DataTypes.ENUM('announcement', 'general', 'media', 'event'),
      defaultValue: 'general',
      allowNull: false,
    },
    is_default: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },
    allowed_roles: {
      type: DataTypes.JSONB,
      defaultValue: ['admin', 'moderator', 'member'],
      allowNull: false,
    },
    order: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      allowNull: false,
    },
  },
  {
    tableName: 'community_channels',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['community_id'] },
      { fields: ['type'] },
    ],
  }
);

module.exports = CommunityChannel;
