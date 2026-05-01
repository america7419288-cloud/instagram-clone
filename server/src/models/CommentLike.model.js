// server/src/models/CommentLike.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const CommentLike = sequelize.define(
  'CommentLike',
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

    comment_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'comments', key: 'id' },
      onDelete: 'CASCADE',
    },
  },
  {
    tableName: 'comment_likes',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['comment_id'] },
      { fields: ['user_id'] },
      {
        unique: true,
        fields: ['user_id', 'comment_id'],
        name: 'unique_user_comment_like',
      },
    ],
  }
);

module.exports = CommentLike;