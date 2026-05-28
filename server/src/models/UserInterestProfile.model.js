// server/src/models/UserInterestProfile.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const UserInterestProfile = sequelize.define(
  'UserInterestProfile',
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

    // ─── INTEREST SCORES (0-100) ────────────────────
    interests: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {
        fashion: 0,
        food: 0,
        travel: 0,
        fitness: 0,
        tech: 0,
        music: 0,
        art: 0,
        gaming: 0,
        beauty: 0,
        sports: 0,
        education: 0,
        entertainment: 0,
        news: 0,
        lifestyle: 0,
        photography: 0,
        humor: 0,
        science: 0,
        health: 0,
        business: 0,
        pets: 0,
      },
    },

    // ─── CONTENT FORMAT PREFERENCES ─────────────────
    formatPreferences: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {
        image: 50,
        video: 50,
        carousel: 50,
        reel: 50,
        story: 50,
      },
    },

    // ─── INTERACTION COUNTS ──────────────────────────
    totalLikes: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
    totalComments: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
    totalShares: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
    totalSaves: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
    totalProfileVisits: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    // ─── ACTIVE HOURS (0-23) & DAYS (0-6) ─────────────
    activeHours: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {},
    },
    activeDays: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {},
    },

    // ─── RECENT RECS AND FEEDBACK ─────────────────────
    // [{ authorId, score, lastInteraction }]
    recentAuthors: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },
    // [{ tag, score, lastSeen }]
    recentHashtags: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },
    // [{ contentId, reason, addedAt }]
    notInterested: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },

    // ─── SESSION STATS ────────────────────────────────
    lastActiveAt: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
    averageSessionDuration: {
      type: DataTypes.DOUBLE,
      allowNull: false,
      defaultValue: 0, // in minutes
    },
    sessionsPerDay: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 1,
    },
  },
  {
    tableName: 'user_interest_profiles',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['user_id'], unique: true },
    ],
  }
);

module.exports = UserInterestProfile;
