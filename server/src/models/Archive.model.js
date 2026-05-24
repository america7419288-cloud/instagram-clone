const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Archive = sequelize.define(
  'Archive',
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
    contentId: {
      type: DataTypes.UUID,
      allowNull: false,
      field: 'content_id',
    },
    contentType: {
      type: DataTypes.ENUM('post', 'story', 'reel'),
      allowNull: false,
      field: 'content_type',
    },
    archivedAt: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
      field: 'archived_at',
    },
    autoArchived: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'auto_archived',
    },
  },
  {
    tableName: 'archives',
    timestamps: true,
    underscored: true,
    indexes: [
      {
        fields: ['user_id', 'content_type', 'archived_at'],
      },
    ],
  }
);

module.exports = Archive;
