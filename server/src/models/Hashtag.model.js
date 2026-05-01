// server/src/models/Hashtag.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Hashtag = sequelize.define(
  'Hashtag',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    // Stored WITHOUT the # symbol
    // Example: "travel" not "#travel"
    name: {
      type: DataTypes.STRING(100),
      allowNull: false,
      unique: true,
      validate: {
        notEmpty: { msg: 'Hashtag name cannot be empty' },
        len: {
          args: [1, 100],
          msg: 'Hashtag must be between 1-100 characters',
        },
      },
    },

    // Cached count for performance
    // Update this when posts are added/removed
    post_count: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
  },
  {
    tableName: 'hashtags',
    timestamps: true,
    underscored: true,
    indexes: [
      { unique: true, fields: ['name'] },
      { fields: ['post_count'] },
    ],
    hooks: {
      beforeSave: (hashtag) => {
        // Always lowercase hashtags
        hashtag.name = hashtag.name.toLowerCase().trim();
      },
    },
  }
);

module.exports = Hashtag;