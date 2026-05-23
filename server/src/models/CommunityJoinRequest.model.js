// server/src/models/CommunityJoinRequest.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const CommunityJoinRequest = sequelize.define(
  'CommunityJoinRequest',
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
    message: {
      type: DataTypes.STRING(255),
      allowNull: true,
      defaultValue: '',
    },
    status: {
      type: DataTypes.ENUM('pending', 'approved', 'rejected'),
      defaultValue: 'pending',
      allowNull: false,
    },
  },
  {
    tableName: 'community_join_requests',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['community_id'] },
      { fields: ['user_id'] },
    ],
  }
);

module.exports = CommunityJoinRequest;
