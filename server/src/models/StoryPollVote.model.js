// server/src/models/StoryPollVote.model.js

const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const StoryPollVote = sequelize.define(
    'StoryPollVote',
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

        pollId: {
            type: DataTypes.UUID,
            allowNull: false,
            references: { model: 'story_polls', key: 'id' },
            onDelete: 'CASCADE',
        },

        userId: {
            type: DataTypes.UUID,
            allowNull: false,
            references: { model: 'users', key: 'id' },
            onDelete: 'CASCADE',
        },

        // ─── Which option voted ───────────────────────────
        // 'a' or 'b'
        option: {
            type: DataTypes.ENUM('a', 'b'),
            allowNull: false,
        },
    },
    {
        tableName: 'story_poll_votes',
        underscored: true,
        timestamps: true,
        indexes: [
            {
                // One vote per user per story
                unique: true,
                fields: ['story_id', 'user_id'],
            },
            { fields: ['poll_id'] },
        ],
    }
);

module.exports = StoryPollVote;