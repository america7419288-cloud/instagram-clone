// server/src/models/SeenContent.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const SeenContent = sequelize.define(
  'SeenContent',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      unique: true,
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },

    // Array of UUIDs of posts / reels seen by user
    contentIds: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },

    expiresAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
  },
  {
    tableName: 'seen_contents',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['user_id'], unique: true },
    ],
  }
);

module.exports = SeenContent;
