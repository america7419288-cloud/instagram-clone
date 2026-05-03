// server/src/models/StoryAnswer.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const StoryAnswer = sequelize.define(
    'StoryAnswer',
    {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true,
        },

        questionId: {
            type: DataTypes.UUID,
            allowNull: false,
            references: { model: 'story_questions', key: 'id' },
            onDelete: 'CASCADE',
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

        // ─── The answer text ───────────────────────────────
        answer: {
            type: DataTypes.STRING(500),
            allowNull: false,
            validate: {
                notEmpty: true,
                len: [1, 500],
            },
        },
    },
    {
        tableName: 'story_answers',
        underscored: true,
        timestamps: true,
        indexes: [
            { fields: ['question_id'] },
            { fields: ['story_id'] },
            { fields: ['user_id'] },
            // One answer per user per question
            {
                unique: true,
                fields: ['question_id', 'user_id'],
            },
        ],
    }
);

module.exports = StoryAnswer;