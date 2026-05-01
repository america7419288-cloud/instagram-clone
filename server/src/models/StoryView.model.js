// server/src/models/StoryView.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const StoryView = sequelize.define(
  'StoryView',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    // Which story was viewed
    story_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'stories',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Who viewed it
    viewer_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // When they viewed
    viewed_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
      allowNull: false,
    },
  },
  {
    tableName: 'story_views',
    timestamps: false,  // We use viewed_at instead
    underscored: true,
    indexes: [
      { fields: ['story_id'] },
      { fields: ['viewer_id'] },
      {
        // Each user can only view a story once
        unique: true,
        fields: ['story_id', 'viewer_id'],
        name: 'unique_story_view',
      },
    ],
  }
);

module.exports = StoryView;