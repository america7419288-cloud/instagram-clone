// server/src/models/StoryHighlightItem.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const StoryHighlightItem = sequelize.define(
    'StoryHighlightItem',
    {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true,
        },

        highlightId: {
            type: DataTypes.UUID,
            allowNull: false,
            references: { model: 'story_highlights', key: 'id' },
            onDelete: 'CASCADE',
        },

        // ─── Reference to story (may be expired/deleted) ──
        // We keep the story data even after expiry for highlights
        storyId: {
            type: DataTypes.UUID,
            allowNull: false,
            // No FK constraint → stories can be deleted
            // without removing from highlights
        },

        // ─── Cached story data (in case story is deleted) ─
        storyUrl: {
            type: DataTypes.TEXT,
            allowNull: true,
        },

        storyThumbnailUrl: {
            type: DataTypes.TEXT,
            allowNull: true,
        },

        storyMediaType: {
            type: DataTypes.ENUM('image', 'video'),
            allowNull: false,
            defaultValue: 'image',
        },

        // ─── Display order ────────────────────────────────
        order: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0,
        },
    },
    {
        tableName: 'story_highlight_items',
        underscored: true,
        timestamps: true,
        indexes: [
            { fields: ['highlight_id'] },
            {
                unique: true,
                fields: ['highlight_id', 'story_id'],
            },
        ],
    }
);

module.exports = StoryHighlightItem;