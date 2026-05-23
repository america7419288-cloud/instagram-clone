// server/src/models/Report.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Report = sequelize.define(
  'Report',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    // Who submitted the report
    reported_by: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Optional: The user being reported
    reported_user_id: {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Optional: The message being reported (for harassment/spam in DM)
    reported_message_id: {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'messages',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Reason for report ('spam', 'harassment', 'hate_speech', 'violence', 'nudity', 'scam', 'other')
    report_type: {
      type: DataTypes.STRING(100),
      allowNull: false,
    },

    // Additional description/details
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
    },

    // Status: 'pending', 'reviewed', 'resolved', 'dismissed'
    status: {
      type: DataTypes.STRING(50),
      defaultValue: 'pending',
      allowNull: false,
    },
  },
  {
    tableName: 'reports',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['reported_by'] },
      { fields: ['reported_user_id'] },
      { fields: ['reported_message_id'] },
      { fields: ['status'] },
    ],
  }
);

module.exports = Report;
