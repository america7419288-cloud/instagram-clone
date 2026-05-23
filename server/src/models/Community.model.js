// server/src/models/Community.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Community = sequelize.define(
  'Community',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },
    name: {
      type: DataTypes.STRING(100),
      allowNull: false,
      unique: {
        name: 'unique_community_name',
        msg: 'A community with this name already exists',
      },
      validate: {
        len: [3, 100],
      },
    },
    handle: {
      type: DataTypes.STRING(30),
      allowNull: false,
      unique: {
        name: 'unique_community_handle',
        msg: 'This handle is already taken',
      },
      validate: {
        is: /^[a-zA-Z0-9_]{3,30}$/,
      },
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
      defaultValue: '',
    },
    avatar_url: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    cover_url: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    category: {
      type: DataTypes.STRING(50),
      allowNull: false,
    },
    privacy: {
      type: DataTypes.ENUM('public', 'private'),
      defaultValue: 'public',
      allowNull: false,
    },
    created_by: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },
    member_count: {
      type: DataTypes.INTEGER,
      defaultValue: 1,
      allowNull: false,
    },
    max_members: {
      type: DataTypes.INTEGER,
      defaultValue: 50000,
      allowNull: false,
    },
    is_verified: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },
    tags: {
      type: DataTypes.JSONB,
      defaultValue: [],
      allowNull: false,
    },
    invite_link: {
      type: DataTypes.STRING(255),
      allowNull: true,
      unique: true,
    },
    settings: {
      type: DataTypes.JSONB,
      defaultValue: {
        postApprovalRequired: false,
        onlyAdminsCanPost: false,
        allowMemberInvites: true,
        showMemberCount: true,
        minimumAccountAge: 0,
      },
      allowNull: false,
    },
    stats: {
      type: DataTypes.JSONB,
      defaultValue: {
        totalPosts: 0,
        totalMessages: 0,
        weeklyActiveMembers: 0,
      },
      allowNull: false,
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
      allowNull: false,
    },
  },
  {
    tableName: 'communities',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['handle'] },
      { fields: ['category'] },
      { fields: ['member_count'] },
    ],
    hooks: {
      beforeSave: (community) => {
        if (community.handle) {
          community.handle = community.handle.toLowerCase().trim();
        }
      },
    },
  }
);

module.exports = Community;
