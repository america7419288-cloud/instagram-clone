// server/src/models/ReelLike.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const ReelLike = sequelize.define(
    'ReelLike',
    {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true,
        },

        reelId: {
            type: DataTypes.UUID,
            allowNull: false,
            references: {
                model: 'reels',
                key: 'id',
            },
            onDelete: 'CASCADE',
        },

        userId: {
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
        tableName: 'reel_likes',
        underscored: true,
        timestamps: true,
        // ─── Prevent duplicate likes ───────────────────────
        indexes: [
            {
                unique: true,
                fields: ['reel_id', 'user_id'],
                name: 'unique_reel_like',
            },
            { fields: ['reel_id'] },
            { fields: ['user_id'] },
        ],
    }
);

module.exports = ReelLike;