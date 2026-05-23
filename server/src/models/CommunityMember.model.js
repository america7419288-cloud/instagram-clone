// server/src/models/CommunityMember.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const CommunityMember = sequelize.define(
  'CommunityMember',
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
    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },
    role: {
      type: DataTypes.ENUM('owner', 'admin', 'moderator', 'member'),
      defaultValue: 'member',
      allowNull: false,
    },
    is_banned: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },
    banned_until: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    banned_reason: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    muted_until: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    notifications: {
      type: DataTypes.ENUM('all', 'mentions', 'none'),
      defaultValue: 'all',
      allowNull: false,
    },
  },
  {
    tableName: 'community_members',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['community_id'] },
      { fields: ['user_id'] },
      {
        unique: true,
        fields: ['community_id', 'user_id'],
        name: 'unique_community_member',
      },
    ],
  }
);

module.exports = CommunityMember;
