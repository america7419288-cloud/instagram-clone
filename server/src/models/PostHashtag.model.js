// server/src/models/PostHashtag.model.js
// Junction table: links posts to hashtags

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const PostHashtag = sequelize.define(
  'PostHashtag',
  {
    post_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'posts', key: 'id' },
      onDelete: 'CASCADE',
      primaryKey: true,
    },

    hashtag_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'hashtags', key: 'id' },
      onDelete: 'CASCADE',
      primaryKey: true,
    },
  },
  {
    tableName: 'post_hashtags',
    timestamps: false,
    underscored: true,
    indexes: [
      { fields: ['post_id'] },
      { fields: ['hashtag_id'] },
    ],
  }
);

module.exports = PostHashtag;
