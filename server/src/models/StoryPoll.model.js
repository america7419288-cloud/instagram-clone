// server/src/models/StoryPoll.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const StoryPoll = sequelize.define(
    'StoryPoll',
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

        // ─── Poll question ────────────────────────────────
        question: {
            type: DataTypes.STRING(200),
            allowNull: false,
            defaultValue: 'Vote',
        },

        // ─── Two options ──────────────────────────────────
        optionA: {
            type: DataTypes.STRING(100),
            allowNull: false,
            defaultValue: 'Yes',
        },

        optionB: {
            type: DataTypes.STRING(100),
            allowNull: false,
            defaultValue: 'No',
        },

        // ─── Vote counts (denormalized for speed) ─────────
        votesA: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0,
        },

        votesB: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0,
        },
    },
    {
        tableName: 'story_polls',
        underscored: true,
        timestamps: true,
        indexes: [
            { fields: ['story_id'], unique: true },
        ],
    }
);

module.exports = StoryPoll;