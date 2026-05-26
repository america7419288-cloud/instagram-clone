const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const AdImpression = sequelize.define(
  'AdImpression',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },
    adCreativeId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'ad_creatives',
        key: 'id',
      },
      onDelete: 'CASCADE',
      field: 'ad_creative_id',
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
    advertiserId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'advertisers',
        key: 'id',
      },
      onDelete: 'CASCADE',
      field: 'advertiser_id',
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
      field: 'user_id',
    },
    action: {
      type: DataTypes.ENUM(
        'impression',
        'click',
        'skip',
        'video_start',
        'video_complete',
        'swipe_up',
        'cta_click'
      ),
      allowNull: false,
    },
    placement: {
      type: DataTypes.ENUM('feed', 'reels', 'stories', 'explore'),
      allowNull: false,
    },
    deviceType: {
      type: DataTypes.ENUM('android', 'ios'),
      defaultValue: 'android',
      field: 'device_type',
    },
    costCharged: {
      type: DataTypes.INTEGER, // in cents
      defaultValue: 0,
      field: 'cost_charged',
    },
    timestamp: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    tableName: 'ad_impressions',
    timestamps: false, // only timestamp field is used
    underscored: true,
  }
);

module.exports = AdImpression;
