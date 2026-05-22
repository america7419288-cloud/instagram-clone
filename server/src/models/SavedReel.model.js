// server/src/models/SavedReel.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const SavedReel = sequelize.define(
  'SavedReel',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    // The user who bookmarked the reel
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },

    // The reel that was bookmarked
    reelId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'reels', key: 'id' },
      onDelete: 'CASCADE',
    },
  },
  {
    tableName: 'saved_reels',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['user_id'] },
      { fields: ['reel_id'] },
      {
        // Prevent duplicate saves
        unique: true,
        fields: ['user_id', 'reel_id'],
        name: 'unique_user_reel_save',
      },
    ],
  }
);

module.exports = SavedReel;
