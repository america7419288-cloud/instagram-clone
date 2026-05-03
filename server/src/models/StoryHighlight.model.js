// server/src/models/StoryHighlight.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const StoryHighlight = sequelize.define(
    'StoryHighlight',
    {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true,
        },

        userId: {
            type: DataTypes.UUID,
            allowNull: false,
            references: { model: 'users', key: 'id' },
            onDelete: 'CASCADE',
        },

        // ─── Display name ─────────────────────────────────
        // e.g. "Travel", "Food", "Work"
        title: {
            type: DataTypes.STRING(50),
            allowNull: false,
            validate: {
                notEmpty: true,
                len: [1, 50],
            },
        },

        // ─── Cover image (from one of the stories) ────────
        coverUrl: {
            type: DataTypes.TEXT,
            allowNull: true,
        },

        // ─── Cloudinary public ID of cover ────────────────
        coverPublicId: {
            type: DataTypes.STRING(255),
            allowNull: true,
        },

        // ─── Story count (denormalized) ───────────────────
        storiesCount: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0,
        },
    },
    {
        tableName: 'story_highlights',
        underscored: true,
        timestamps: true,
        indexes: [
            { fields: ['user_id'] },
        ],
    }
);

module.exports = StoryHighlight;