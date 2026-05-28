// server/src/models/ContentScoreCache.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const ContentScoreCache = sequelize.define(
  'ContentScoreCache',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    contentId: {
      type: DataTypes.UUID,
      allowNull: false,
    },

    contentType: {
      type: DataTypes.STRING(50),
      allowNull: false, // 'post', 'reel', 'story'
    },

    authorId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },

    qualityScore: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    engagementRate: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    viralityScore: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    freshnessScore: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    authorReputationScore: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    totalEngagements: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    likeVelocity: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    commentVelocity: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    shareVelocity: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    categories: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },

    hashtags: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },

    computedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },

    expiresAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
  },
  {
    tableName: 'content_score_caches',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['content_id', 'content_type'], unique: true },
      { fields: ['content_type', 'quality_score'] },
    ],
  }
);

module.exports = ContentScoreCache;
