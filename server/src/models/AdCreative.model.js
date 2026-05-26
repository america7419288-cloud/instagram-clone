const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const AdCreative = sequelize.define(
  'AdCreative',
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
    type: {
      type: DataTypes.ENUM('image', 'video', 'carousel', 'story_image', 'story_video'),
      allowNull: false,
    },
    // Media URLs and dimensions
    imageUrl: {
      type: DataTypes.STRING(500),
      allowNull: true,
      field: 'image_url',
    },
    imageWidth: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'image_width',
    },
    imageHeight: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'image_height',
    },
    videoUrl: {
      type: DataTypes.STRING(500),
      allowNull: true,
      field: 'video_url',
    },
    videoDuration: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'video_duration',
    },
    videoThumbnailUrl: {
      type: DataTypes.STRING(500),
      allowNull: true,
      field: 'video_thumbnail_url',
    },
    carouselCards: {
      type: DataTypes.JSONB,
      defaultValue: [], // list of {imageUrl, headline, description, ctaUrl}
      field: 'carousel_cards',
    },
    // Creative Copy
    advertiserName: {
      type: DataTypes.STRING(60),
      allowNull: false,
      field: 'advertiser_name',
    },
    advertiserAvatarUrl: {
      type: DataTypes.STRING(500),
      allowNull: true,
      field: 'advertiser_avatar_url',
    },
    headline: {
      type: DataTypes.STRING(40),
      allowNull: true,
    },
    primaryText: {
      type: DataTypes.STRING(125),
      allowNull: false,
      field: 'primary_text',
    },
    description: {
      type: DataTypes.STRING(30),
      allowNull: true,
    },
    // Call-To-Action (CTA) details
    ctaType: {
      type: DataTypes.ENUM(
        'shop_now',
        'learn_more',
        'sign_up',
        'download',
        'book_now',
        'contact_us',
        'watch_more',
        'apply_now',
        'get_offer',
        'install_now',
        'order_now',
        'subscribe',
        'no_button'
      ),
      defaultValue: 'learn_more',
      field: 'cta_type',
    },
    ctaUrl: {
      type: DataTypes.STRING(500),
      allowNull: false,
      field: 'cta_url',
    },
    // Story specific settings
    storySwipeUpText: {
      type: DataTypes.STRING(30),
      defaultValue: 'See more',
      field: 'story_swipe_up_text',
    },
    storyOverlayColor: {
      type: DataTypes.STRING(10),
      defaultValue: '#000000',
      field: 'story_overlay_color',
    },
    // Campaign Status
    status: {
      type: DataTypes.ENUM('active', 'paused', 'archived'),
      defaultValue: 'active',
    },
    // Aggregated Metrics per Creative
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
  },
  {
    tableName: 'ad_creatives',
    timestamps: true,
    underscored: true,
  }
);

module.exports = AdCreative;
