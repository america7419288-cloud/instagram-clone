// server/src/models/Note.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Note = sequelize.define(
  'Note',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },

    // Author of the note
    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    // Note content (max 60 characters)
    text: {
      type: DataTypes.STRING(60),
      allowNull: false,
      validate: {
        notEmpty: { msg: 'Note text cannot be empty' },
        len: {
          args: [1, 60],
          msg: 'Note must be between 1 and 60 characters',
        },
      },
    },

    // Note audience: 'followers' or 'close_friends'
    audience: {
      type: DataTypes.ENUM('followers', 'close_friends'),
      defaultValue: 'followers',
      allowNull: false,
    },

    // Expiry date (defaults to 24 hours from creation)
    expires_at: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: () => {
        const now = new Date();
        now.setHours(now.getHours() + 24);
        return now;
      },
    },
  },
  {
    tableName: 'notes',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['user_id'] },
      { fields: ['expires_at'] },
      { fields: ['created_at'] },
    ],
  }
);

module.exports = Note;
