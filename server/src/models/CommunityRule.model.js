// server/src/models/CommunityRule.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const CommunityRule = sequelize.define(
  'CommunityRule',
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
    title: {
      type: DataTypes.STRING(100),
      allowNull: false,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
      defaultValue: '',
    },
    order: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      allowNull: false,
    },
  },
  {
    tableName: 'community_rules',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['community_id'] },
    ],
  }
);

module.exports = CommunityRule;
