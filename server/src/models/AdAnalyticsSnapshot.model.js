const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const AdAnalyticsSnapshot = sequelize.define(
  'AdAnalyticsSnapshot',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },
    campaignId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'campaigns',
        key: 'id',
      },
      onDelete: 'CASCADE',
      field: 'campaign_id',
    },
    date: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    impressions: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    clicks: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    skips: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    videoViews: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      field: 'video_views',
    },
    videoCompletions: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      field: 'video_completions',
    },
    reach: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    spend: {
      type: DataTypes.INTEGER, // in cents
      defaultValue: 0,
    },
    // Placement aggregates
    feedImpressions: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      field: 'feed_impressions',
    },
    reelImpressions: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      field: 'reel_impressions',
    },
    storyImpressions: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      field: 'story_impressions',
    },
  },
  {
    tableName: 'ad_analytics_snapshots',
    timestamps: true,
    underscored: true,
    indexes: [
      {
        unique: true,
        fields: ['campaign_id', 'date'],
      },
    ],
  }
);

module.exports = AdAnalyticsSnapshot;
