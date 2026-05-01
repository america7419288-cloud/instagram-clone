// server/src/models/Follower.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Follower = sequelize.define(
  'Follower',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    // The person WHO IS FOLLOWING
    follower_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },

    // The person BEING FOLLOWED
    following_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },

    // Status of the follow relationship
    // pending  = request sent (private account)
    // accepted = following (public account auto-accepts)
    // rejected = request denied
    status: {
      type: DataTypes.ENUM('pending', 'accepted', 'rejected'),
      defaultValue: 'accepted',
      allowNull: false,
    },
  },
  {
    tableName: 'followers',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['follower_id'] },
      { fields: ['following_id'] },
      { fields: ['status'] },
      {
        // Prevent duplicate follows
        unique: true,
        fields: ['follower_id', 'following_id'],
        name: 'unique_follow_relationship',
      },
    ],
    validate: {
      // Can't follow yourself
      notSelf() {
        if (this.follower_id === this.following_id) {
          throw new Error('You cannot follow yourself');
        }
      },
    },
  }
);

module.exports = Follower;