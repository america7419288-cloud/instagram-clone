// server/src/models/StoryReaction.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const StoryReaction = sequelize.define(
    'StoryReaction',
    {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true,
        },

        storyId: {
            type: DataTypes.UUID,
            allowNull: false,
            references: { model: 'stories', key: 'id' },
            onDelete: 'CASCADE',
        },

        userId: {
            type: DataTypes.UUID,
            allowNull: false,
            references: { model: 'users', key: 'id' },
            onDelete: 'CASCADE',
        },

        // ─── Emoji reaction ────────────────────────────────
        // Allowed: ❤️ 😮 😂 😢 😡 🔥 👏
        emoji: {
            type: DataTypes.STRING(10),
            allowNull: false,
        },
    },
    {
        tableName: 'story_reactions',
        underscored: true,
        timestamps: true,
        indexes: [
            {
                // One reaction per user per story
                unique: true,
                fields: ['story_id', 'user_id'],
            },
            { fields: ['story_id'] },
        ],
    }
);

module.exports = StoryReaction;