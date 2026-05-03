// server/src/models/StoryQuestion.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const StoryQuestion = sequelize.define(
    'StoryQuestion',
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

        // ─── The question prompt set by story creator ──────
        // e.g. "Ask me anything" or "What do you think?"
        question: {
            type: DataTypes.STRING(200),
            allowNull: false,
            defaultValue: 'Ask me anything',
        },

        // ─── Count of answers received ─────────────────────
        answersCount: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0,
        },
        // ─── Positioning ──────────────────────────────────
        x: {
            type: DataTypes.FLOAT,
            allowNull: false,
            defaultValue: 0.5,
        },
        y: {
            type: DataTypes.FLOAT,
            allowNull: false,
            defaultValue: 0.5,
        },
        width: {
            type: DataTypes.FLOAT,
            allowNull: false,
            defaultValue: 0,
        },
        height: {
            type: DataTypes.FLOAT,
            allowNull: false,
            defaultValue: 0,
        },
        rotation: {
            type: DataTypes.FLOAT,
            allowNull: false,
            defaultValue: 0,
        },
    },
    {
        tableName: 'story_questions',
        underscored: true,
        timestamps: true,
        indexes: [
            { fields: ['story_id'], unique: true },
        ],
    }
);

module.exports = StoryQuestion;