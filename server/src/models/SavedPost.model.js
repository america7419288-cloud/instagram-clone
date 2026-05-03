// server/src/models/SavedPost.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const SavedPost = sequelize.define(
  'SavedPost',
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
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },

    postId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'posts', key: 'id' },
      onDelete: 'CASCADE',
    },
  },
  {
    tableName: 'saved_posts',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['user_id'] },
      { fields: ['post_id'] },
      {
        unique: true,
        fields: ['user_id', 'post_id'],
        name: 'unique_user_post_save',
      },
    ],
  }
);

module.exports = SavedPost;