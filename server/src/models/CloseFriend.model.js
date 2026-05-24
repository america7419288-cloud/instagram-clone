const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const CloseFriend = sequelize.define(
  'CloseFriend',
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
    friendId: {
      type: DataTypes.UUID,
      allowNull: false,
      field: 'friend_id',
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },
    addedAt: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
      field: 'added_at',
    },
  },
  {
    tableName: 'close_friends',
    timestamps: true,
    underscored: true,
    indexes: [
      {
        unique: true,
        fields: ['user_id', 'friend_id'],
        name: 'unique_user_friend_close',
      },
    ],
  }
);

module.exports = CloseFriend;
