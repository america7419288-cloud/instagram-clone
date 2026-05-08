// server/src/models/PostTag.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const PostTag = sequelize.define(
  'PostTag',
  {
    id: {
      type:         DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey:   true,
    },

    postId: {
      type:      DataTypes.UUID,
      allowNull: false,
      references: { model: 'posts', key: 'id' },
      onDelete:  'CASCADE',
    },

    // ─── Tagged user ──────────────────────────────────
    userId: {
      type:      DataTypes.UUID,
      allowNull: false,
      references: { model: 'users', key: 'id' },
      onDelete:  'CASCADE',
    },

    // ─── Position on image (normalized 0.0 - 1.0) ────
    // x: 0 = left edge, 1 = right edge
    // y: 0 = top edge,  1 = bottom edge
    xPosition: {
      type:         DataTypes.FLOAT,
      allowNull:    false,
      defaultValue: 0.5,
      validate:     { min: 0, max: 1 },
    },

    yPosition: {
      type:         DataTypes.FLOAT,
      allowNull:    false,
      defaultValue: 0.5,
      validate:     { min: 0, max: 1 },
    },

    // ─── Which media index in carousel (0-based) ─────
    mediaIndex: {
      type:         DataTypes.INTEGER,
      allowNull:    false,
      defaultValue: 0,
    },
    
    // ─── Approval Status ──────────────────────────────
    isAccepted: {
      type:         DataTypes.BOOLEAN,
      allowNull:    false,
      defaultValue: false,
    },
  },
  {
    tableName:   'post_tags',
    underscored: true,
    timestamps:  true,
    indexes: [
      { fields: ['post_id'] },
      { fields: ['user_id'] },
      {
        // One tag per user per post per media
        unique: true,
        fields: ['post_id', 'user_id', 'media_index'],
      },
    ],
  }
);

module.exports = PostTag;
