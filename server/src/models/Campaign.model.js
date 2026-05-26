const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Campaign = sequelize.define(
  'Campaign',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
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
    name: {
      type: DataTypes.STRING(100),
      allowNull: false,
    },
    objective: {
      type: DataTypes.ENUM(
        'awareness',
        'traffic',
        'engagement',
        'app_installs',
        'conversions',
        'video_views'
      ),
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM(
        'draft',
        'pending_review',
        'active',
        'paused',
        'completed',
        'rejected'
      ),
      defaultValue: 'draft',
    },
    // Budget
    budgetType: {
      type: DataTypes.ENUM('daily', 'lifetime'),
      defaultValue: 'daily',
      field: 'budget_type',
    },
    budgetAmount: {
      type: DataTypes.INTEGER, // in cents
      allowNull: false,
      validate: {
        min: 100, // minimum $1.00
      },
      field: 'budget_amount',
    },
    budgetSpent: {
      type: DataTypes.INTEGER, // in cents
      defaultValue: 0,
      field: 'budget_spent',
    },
    // Bid strategy
    bidStrategy: {
      type: DataTypes.ENUM('lowest_cost', 'cost_cap', 'bid_cap'),
      defaultValue: 'lowest_cost',
      field: 'bid_strategy',
    },
    bidAmount: {
      type: DataTypes.INTEGER, // in cents
      allowNull: true,
      field: 'bid_amount',
    },
    // Schedule
    startDate: {
      type: DataTypes.DATE,
      allowNull: false,
      field: 'start_date',
    },
    endDate: {
      type: DataTypes.DATE,
      allowNull: true,
      field: 'end_date',
    },
    timezone: {
      type: DataTypes.STRING(50),
      defaultValue: 'UTC',
    },
    activeDays: {
      type: DataTypes.JSONB,
      defaultValue: [0, 1, 2, 3, 4, 5, 6],
      field: 'active_days',
    },
    activeHoursStart: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      field: 'active_hours_start',
    },
    activeHoursEnd: {
      type: DataTypes.INTEGER,
      defaultValue: 23,
      field: 'active_hours_end',
    },
    // Targeting
    ageMin: {
      type: DataTypes.INTEGER,
      defaultValue: 18,
      field: 'age_min',
    },
    ageMax: {
      type: DataTypes.INTEGER,
      defaultValue: 65,
      field: 'age_max',
    },
    gender: {
      type: DataTypes.ENUM('all', 'male', 'female'),
      defaultValue: 'all',
    },
    locations: {
      type: DataTypes.JSONB,
      defaultValue: [], // list of {country, state, city}
    },
    interests: {
      type: DataTypes.JSONB,
      defaultValue: [],
    },
    devices: {
      type: DataTypes.JSONB,
      defaultValue: ['all'],
    },
    includeCustomAudience: {
      type: DataTypes.JSONB,
      defaultValue: [],
      field: 'include_custom_audience',
    },
    excludeCustomAudience: {
      type: DataTypes.JSONB,
      defaultValue: [],
      field: 'exclude_custom_audience',
    },
    retargetEngaged: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'retarget_engaged',
    },
    retargetVisitors: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'retarget_visitors',
    },
    // Placements
    placementFeed: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
      field: 'placement_feed',
    },
    placementReels: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
      field: 'placement_reels',
    },
    placementStories: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
      field: 'placement_stories',
    },
    placementExplore: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'placement_explore',
    },
    // Cumulative Analytics Metrics
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
    frequency: {
      type: DataTypes.FLOAT,
      defaultValue: 0,
    },
    websiteClicks: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      field: 'website_clicks',
    },
    appInstalls: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      field: 'app_installs',
    },
    purchases: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    // Moderation
    rejectionReason: {
      type: DataTypes.STRING(255),
      allowNull: true,
      field: 'rejection_reason',
    },
    reviewedAt: {
      type: DataTypes.DATE,
      allowNull: true,
      field: 'reviewed_at',
    },
    reviewedBy: {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'SET NULL',
      field: 'reviewed_by',
    },
    // VIRTUAL COMPUTED GETTERS
    ctr: {
      type: DataTypes.VIRTUAL,
      get() {
        const imps = this.getDataValue('impressions') || 0;
        const clks = this.getDataValue('clicks') || 0;
        if (imps === 0) return '0.00';
        return ((clks / imps) * 100).toFixed(2);
      },
    },
    cpm: {
      type: DataTypes.VIRTUAL,
      get() {
        const imps = this.getDataValue('impressions') || 0;
        const spent = this.getDataValue('budgetSpent') || 0;
        if (imps === 0) return '0.00';
        return ((spent / imps) * 1000).toFixed(2);
      },
    },
    cpc: {
      type: DataTypes.VIRTUAL,
      get() {
        const clks = this.getDataValue('clicks') || 0;
        const spent = this.getDataValue('budgetSpent') || 0;
        if (clks === 0) return '0.00';
        return (spent / clks).toFixed(2);
      },
    },
  },
  {
    tableName: 'campaigns',
    timestamps: true,
    underscored: true,
  }
);

module.exports = Campaign;
