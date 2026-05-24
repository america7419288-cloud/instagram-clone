const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const MutedAccount = sequelize.define(
  'MutedAccount',
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
      field: 'user_id',
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },
    mutedUserId: {
      type: DataTypes.UUID,
      allowNull: false,
      field: 'muted_user_id',
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },
    mutePosts: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
      field: 'mute_posts',
    },
    muteStories: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'mute_stories',
    },
    mutedAt: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
      field: 'muted_at',
    },
  },
  {
    tableName: 'muted_accounts',
    timestamps: true,
    underscored: true,
    indexes: [
      {
        unique: true,
        fields: ['user_id', 'muted_user_id'],
        name: 'unique_user_muted_relationship',
      },
    ],
  }
);

module.exports = MutedAccount;
