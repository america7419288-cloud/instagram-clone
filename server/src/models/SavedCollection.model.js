const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const SavedCollection = sequelize.define(
  'SavedCollection',
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
    name: {
      type: DataTypes.STRING(60),
      allowNull: false,
      validate: {
        len: [1, 60],
      },
    },
    coverPostId: {
      type: DataTypes.UUID,
      allowNull: true,
      field: 'cover_post_id',
      references: { model: 'posts', key: 'id' },
      onDelete: 'SET NULL',
    },
    postCount: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      field: 'post_count',
    },
    isDefault: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'is_default',
    },
  },
  {
    tableName: 'saved_collections',
    timestamps: true,
    underscored: true,
  }
);

module.exports = SavedCollection;
