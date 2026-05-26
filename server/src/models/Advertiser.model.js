const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Advertiser = sequelize.define(
  'Advertiser',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'SET NULL',
      field: 'user_id',
    },
    businessName: {
      type: DataTypes.STRING(100),
      allowNull: false,
      validate: {
        notEmpty: true,
      },
    },
    businessEmail: {
      type: DataTypes.STRING(255),
      allowNull: false,
      validate: {
        isEmail: true,
      },
    },
    businessWebsite: {
      type: DataTypes.STRING(255),
      allowNull: true,
      validate: {
        isUrl: true,
      },
    },
    businessCategory: {
      type: DataTypes.ENUM(
        'ecommerce', 'food', 'fashion', 'tech',
        'health', 'beauty', 'travel', 'education',
        'finance', 'entertainment', 'gaming',
        'real_estate', 'automotive', 'sports', 'other'
      ),
      allowNull: false,
    },
    logoUrl: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    isVerified: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    isAppOwner: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    balance: {
      type: DataTypes.INTEGER,
      defaultValue: 0, // in cents
    },
    currency: {
      type: DataTypes.STRING(10),
      defaultValue: 'USD',
    },
    totalSpent: {
      type: DataTypes.INTEGER,
      defaultValue: 0, // in cents
    },
    status: {
      type: DataTypes.ENUM('pending', 'active', 'suspended'),
      defaultValue: 'active',
    },
  },
  {
    tableName: 'advertisers',
    timestamps: true,
    underscored: true,
  }
);

module.exports = Advertiser;
