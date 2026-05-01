// server/src/models/Block.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Block = sequelize.define(
  'Block',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    // Who is doing the blocking
    blocker_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Who is being blocked
    blocked_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },
  },
  {
    tableName: 'blocks',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['blocker_id'] },
      { fields: ['blocked_id'] },
      {
        unique: true,
        fields: ['blocker_id', 'blocked_id'],
        name: 'unique_block_relationship',
      },
    ],
  }
);

module.exports = Block;