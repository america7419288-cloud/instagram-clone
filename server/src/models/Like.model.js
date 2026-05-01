// server/src/models/Like.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Like = sequelize.define(
  'Like',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },

    post_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'posts', key: 'id' },
      onDelete: 'CASCADE',
    },
  },
  {
    tableName: 'likes',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['post_id'] },
      { fields: ['user_id'] },
      {
        // Prevent duplicate likes
        unique: true,
        fields: ['user_id', 'post_id'],
        name: 'unique_user_post_like',
      },
    ],
  }
);

module.exports = Like;