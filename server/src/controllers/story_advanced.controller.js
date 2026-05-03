// server/src/controllers/story_advanced.controller.js

const { v4: uuidv4 } = require('uuid');
const {
    Story,
    StoryPoll,
    StoryPollVote,
    StoryQuestion,
    StoryAnswer,
    StoryReaction,
    StoryHighlight,
    StoryHighlightItem,
    User,
    Conversation,
    ConversationParticipant,
    Message,
} = require('../models');
const { successResponse, errorResponse } = require('../utils/response.utils');
const { createNotification } = require('../services/notification.service');
const { emitToUser } = require('../services/socket.service');

// ─────────────────────────────────────────────────────
// ALLOWED REACTION EMOJIS
// ─────────────────────────────────────────────────────
const ALLOWED_EMOJIS = ['❤️', '😮', '😂', '😢', '😡', '🔥', '👏'];

// ─────────────────────────────────────────────────────
// POLL — VOTE
// POST /api/stories/:storyId/poll/vote
// body: { option: 'a' | 'b' }
// ─────────────────────────────────────────────────────
const votePoll = async (req, res) => {
    try {
        const { storyId } = req.params;
        const userId = req.user.id;
        const { option } = req.body;

        // ─── Validate option ──────────────────────────────
        if (!['a', 'b'].includes(option)) {
            return errorResponse(res, 'Option must be "a" or "b"', 400);
        }

        // ─── Check story exists ───────────────────────────
        const story = await Story.findByPk(storyId, {
            attributes: ['id', 'userId', 'expiresAt'],
        });
        if (!story) return errorResponse(res, 'Story not found', 404);

        // ─── Check story has poll ─────────────────────────
        const poll = await StoryPoll.findOne({ where: { storyId } });
        if (!poll) return errorResponse(res, 'This story has no poll', 404);

        // ─── Check already voted ──────────────────────────
        const existingVote = await StoryPollVote.findOne({
            where: { storyId, userId },
        });
        if (existingVote) {
            return errorResponse(res, 'You have already voted', 400);
        }

        // ─── Create vote ──────────────────────────────────
        await StoryPollVote.create({
            id: uuidv4(),
            storyId,
            pollId: poll.id,
            userId,
            option,
        });

        // ─── Increment vote count ─────────────────────────
        if (option === 'a') {
            await poll.increment('votesA');
        } else {
            await poll.increment('votesB');
        }

        await poll.reload();

        const totalVotes = poll.votesA + poll.votesB;

        return successResponse(res, 'Vote recorded', {
            option,
            votesA: poll.votesA,
            votesB: poll.votesB,
            totalVotes,
            percentA: totalVotes > 0
                ? Math.round((poll.votesA / totalVotes) * 100)
                : 0,
            percentB: totalVotes > 0
                ? Math.round((poll.votesB / totalVotes) * 100)
                : 0,
        });
    } catch (error) {
        console.error('❌ votePoll error:', error);
        return errorResponse(res, 'Failed to vote', 500);
    }
};

// ─────────────────────────────────────────────────────
// POLL — GET RESULTS
// GET /api/stories/:storyId/poll/results
// ─────────────────────────────────────────────────────
const getPollResults = async (req, res) => {
    try {
        const { storyId } = req.params;
        const userId = req.user.id;

        const poll = await StoryPoll.findOne({ where: { storyId } });
        if (!poll) return errorResponse(res, 'No poll found for this story', 404);

        // ─── Did current user vote? ───────────────────────
        const myVote = await StoryPollVote.findOne({
            where: { storyId, userId },
            attributes: ['option'],
        });

        const totalVotes = poll.votesA + poll.votesB;

        return successResponse(res, 'Poll results loaded', {
            question: poll.question,
            optionA: poll.optionA,
            optionB: poll.optionB,
            votesA: poll.votesA,
            votesB: poll.votesB,
            totalVotes,
            percentA: totalVotes > 0
                ? Math.round((poll.votesA / totalVotes) * 100)
                : 0,
            percentB: totalVotes > 0
                ? Math.round((poll.votesB / totalVotes) * 100)
                : 0,
            myVote: myVote?.option || null,
            hasVoted: !!myVote,
        });
    } catch (error) {
        console.error('❌ getPollResults error:', error);
        return errorResponse(res, 'Failed to get poll results', 500);
    }
};

// ─────────────────────────────────────────────────────
// QUESTION — SUBMIT ANSWER
// POST /api/stories/:storyId/question/answer
// body: { answer: string }
// ─────────────────────────────────────────────────────
const answerQuestion = async (req, res) => {
    try {
        const { storyId } = req.params;
        const userId = req.user.id;
        const { answer } = req.body;

        // ─── Validate ─────────────────────────────────────
        if (!answer || answer.trim().length === 0) {
            return errorResponse(res, 'Answer cannot be empty', 400);
        }
        if (answer.trim().length > 500) {
            return errorResponse(res, 'Answer too long (max 500 chars)', 400);
        }

        // ─── Check story + question exist ─────────────────
        const story = await Story.findByPk(storyId, {
            attributes: ['id', 'userId'],
        });
        if (!story) return errorResponse(res, 'Story not found', 404);

        const question = await StoryQuestion.findOne({ where: { storyId } });
        if (!question) {
            return errorResponse(res, 'This story has no question sticker', 404);
        }

        // ─── Check already answered ───────────────────────
        const existing = await StoryAnswer.findOne({
            where: { questionId: question.id, userId },
        });
        if (existing) {
            return errorResponse(res, 'You have already answered this question', 400);
        }

        // ─── Create answer ────────────────────────────────
        const newAnswer = await StoryAnswer.create({
            id: uuidv4(),
            questionId: question.id,
            storyId,
            userId,
            answer: answer.trim(),
        });

        // ─── Increment answer count ───────────────────────
        await question.increment('answersCount');

        // ─── Notify story owner ───────────────────────────
        if (story.userId !== userId) {
            const answerer = await User.findByPk(userId, {
                attributes: ['username'],
            });
            await createNotification({
                recipientId: story.userId,
                senderId: userId,
                type: 'story_answer',
                storyId,
                message: `${answerer?.username} answered your question`,
            });
        }

        return successResponse(res, 'Answer submitted', {
            id: newAnswer.id,
            answer: newAnswer.answer,
            createdAt: newAnswer.createdAt,
        }, 201);
    } catch (error) {
        console.error('❌ answerQuestion error:', error);
        return errorResponse(res, 'Failed to submit answer', 500);
    }
};

// ─────────────────────────────────────────────────────
// QUESTION — GET ANSWERS (story owner only)
// GET /api/stories/:storyId/question/answers
// ─────────────────────────────────────────────────────
const getQuestionAnswers = async (req, res) => {
    try {
        const { storyId } = req.params;
        const userId = req.user.id;

        // ─── Only story owner can see all answers ─────────
        const story = await Story.findByPk(storyId, {
            attributes: ['id', 'userId'],
        });
        if (!story) return errorResponse(res, 'Story not found', 404);
        if (story.userId !== userId) {
            return errorResponse(res, 'Not authorized', 403);
        }

        const question = await StoryQuestion.findOne({ where: { storyId } });
        if (!question) {
            return errorResponse(res, 'No question found', 404);
        }

        const answers = await StoryAnswer.findAll({
            where: { questionId: question.id },
            include: [
                {
                    model: User,
                    as: 'user',
                    attributes: ['id', 'username', 'profilePicture', 'isVerified'],
                },
            ],
            order: [['createdAt', 'DESC']],
        });

        return successResponse(res, 'Answers loaded', {
            question: question.question,
            answersCount: question.answersCount,
            answers: answers.map((a) => ({
                id: a.id,
                answer: a.answer,
                user: a.user,
                createdAt: a.createdAt,
            })),
        });
    } catch (error) {
        console.error('❌ getQuestionAnswers error:', error);
        return errorResponse(res, 'Failed to get answers', 500);
    }
};

// ─────────────────────────────────────────────────────
// REACTION — ADD
// POST /api/stories/:storyId/react
// body: { emoji: '❤️' }
// ─────────────────────────────────────────────────────
const reactToStory = async (req, res) => {
    try {
        const { storyId } = req.params;
        const userId = req.user.id;
        const { emoji } = req.body;

        // ─── Validate emoji ───────────────────────────────
        if (!emoji || !ALLOWED_EMOJIS.includes(emoji)) {
            return errorResponse(
                res,
                `Invalid emoji. Allowed: ${ALLOWED_EMOJIS.join(' ')}`,
                400
            );
        }

        // ─── Check story ──────────────────────────────────
        const story = await Story.findByPk(storyId, {
            attributes: ['id', 'userId'],
        });
        if (!story) return errorResponse(res, 'Story not found', 404);

        // ─── Upsert reaction (update if exists) ──────────
        const [reaction, created] = await StoryReaction.findOrCreate({
            where: { storyId, userId },
            defaults: { id: uuidv4(), storyId, userId, emoji },
        });

        if (!created) {
            // Update emoji if already reacted
            await reaction.update({ emoji });
        }

        // ─── Notify story owner ───────────────────────────
        if (story.userId !== userId) {
            const reactor = await User.findByPk(userId, {
                attributes: ['username'],
            });
            await createNotification({
                recipientId: story.userId,
                senderId: userId,
                type: 'story_reaction',
                storyId,
            });

            // ─── Emit via socket ──────────────────────────
            emitToUser(story.userId, 'story-reaction', {
                storyId,
                emoji,
                username: reactor?.username,
                userId,
            });
        }

        return successResponse(
            res,
            created ? 'Reaction added' : 'Reaction updated',
            { emoji }
        );
    } catch (error) {
        console.error('❌ reactToStory error:', error);
        return errorResponse(res, 'Failed to react to story', 500);
    }
};

// ─────────────────────────────────────────────────────
// REACTION — REMOVE
// DELETE /api/stories/:storyId/react
// ─────────────────────────────────────────────────────
const removeReaction = async (req, res) => {
    try {
        const { storyId } = req.params;
        const userId = req.user.id;

        const reaction = await StoryReaction.findOne({
            where: { storyId, userId },
        });

        if (!reaction) {
            return errorResponse(res, 'No reaction found', 404);
        }

        await reaction.destroy();
        return successResponse(res, 'Reaction removed');
    } catch (error) {
        console.error('❌ removeReaction error:', error);
        return errorResponse(res, 'Failed to remove reaction', 500);
    }
};

// ─────────────────────────────────────────────────────
// STORY REPLY — creates/finds DM conversation
// POST /api/stories/:storyId/reply
// body: { message: string }
// ─────────────────────────────────────────────────────
const replyToStory = async (req, res) => {
    try {
        const { storyId } = req.params;
        const senderId = req.user.id;
        const { message } = req.body;

        if (!message || message.trim().length === 0) {
            return errorResponse(res, 'Message cannot be empty', 400);
        }

        // ─── Get story + owner ────────────────────────────
        const story = await Story.findByPk(storyId, {
            attributes: ['id', 'userId', 'mediaUrl', 'mediaType', 'thumbnailUrl'],
        });
        if (!story) return errorResponse(res, 'Story not found', 404);

        const recipientId = story.userId;

        // ─── Can't reply to own story ─────────────────────
        if (recipientId === senderId) {
            return errorResponse(res, 'Cannot reply to your own story', 400);
        }

        // ─── Find or create DM conversation ──────────────
        let conversation = await _findDmConversation(senderId, recipientId);

        if (!conversation) {
            conversation = await Conversation.create({
                id: uuidv4(),
                isGroup: false,
            });

            await ConversationParticipant.bulkCreate([
                { id: uuidv4(), conversationId: conversation.id, userId: senderId },
                { id: uuidv4(), conversationId: conversation.id, userId: recipientId },
            ]);
        }

        // ─── Create message with story context ────────────
        const newMessage = await Message.create({
            id: uuidv4(),
            conversationId: conversation.id,
            senderId,
            messageType: 'story_reply',
            content: message.trim(),
            // Store story reference in metadata
            metadata: JSON.stringify({
                storyId,
                storyUrl: story.mediaUrl,
                storyType: story.mediaType,
                thumbnailUrl: story.thumbnailUrl,
            }),
        });

        // ─── Update conversation last message ─────────────
        await conversation.update({
            lastMessageId: newMessage.id,
            lastMessageAt: new Date(),
        });

        // ─── Notify recipient ─────────────────────────────
        await createNotification({
            recipientId,
            senderId,
            type: 'story_reply',
            storyId,
        });

        // ─── Emit via socket ──────────────────────────────
        const sender = await User.findByPk(senderId, {
            attributes: ['id', 'username', 'profilePicture'],
        });

        emitToUser(recipientId, 'new-message', {
            conversationId: conversation.id,
            message: {
                id: newMessage.id,
                content: newMessage.content,
                messageType: 'story_reply',
                senderId,
                sender,
                createdAt: newMessage.createdAt,
            },
        });

        return successResponse(res, 'Reply sent', {
            conversationId: conversation.id,
            messageId: newMessage.id,
        }, 201);
    } catch (error) {
        console.error('❌ replyToStory error:', error);
        return errorResponse(res, 'Failed to send reply', 500);
    }
};

// ─────────────────────────────────────────────────────
// HIGHLIGHTS — CREATE
// POST /api/highlights
// body: { title, storyIds: [], coverUrl? }
// ─────────────────────────────────────────────────────
const createHighlight = async (req, res) => {
    try {
        const userId = req.user.id;
        const { title, storyIds, coverUrl } = req.body;

        // ─── Validate ─────────────────────────────────────
        if (!title || title.trim().length === 0) {
            return errorResponse(res, 'Highlight title is required', 400);
        }
        if (title.trim().length > 50) {
            return errorResponse(res, 'Title max 50 characters', 400);
        }

        // ─── Create highlight ─────────────────────────────
        const highlight = await StoryHighlight.create({
            id: uuidv4(),
            userId,
            title: title.trim(),
            coverUrl: coverUrl || null,
        });

        // ─── Add stories if provided ──────────────────────
        if (storyIds && storyIds.length > 0) {
            const stories = await Story.findAll({
                where: { id: storyIds, userId },
                attributes: ['id', 'mediaUrl', 'thumbnailUrl', 'mediaType'],
            });

            if (stories.length > 0) {
                const items = stories.map((s, i) => ({
                    id: uuidv4(),
                    highlightId: highlight.id,
                    storyId: s.id,
                    storyUrl: s.mediaUrl,
                    storyThumbnailUrl: s.thumbnailUrl,
                    storyMediaType: s.mediaType || 'image',
                    order: i,
                }));

                await StoryHighlightItem.bulkCreate(items);
                await highlight.update({
                    storiesCount: stories.length,
                    coverUrl: coverUrl || stories[0].thumbnailUrl || stories[0].mediaUrl,
                });
            }
        }

        await highlight.reload({
            include: [{ model: StoryHighlightItem, as: 'items' }],
        });

        return successResponse(
            res,
            'Highlight created',
            _formatHighlight(highlight),
            201
        );
    } catch (error) {
        console.error('❌ createHighlight error:', error);
        return errorResponse(res, 'Failed to create highlight', 500);
    }
};

// ─────────────────────────────────────────────────────
// HIGHLIGHTS — GET USER HIGHLIGHTS
// GET /api/users/:username/highlights
// ─────────────────────────────────────────────────────
const getUserHighlights = async (req, res) => {
    try {
        const { username } = req.params;

        const user = await User.findOne({
            where: { username },
            attributes: ['id'],
        });
        if (!user) return errorResponse(res, 'User not found', 404);

        const highlights = await StoryHighlight.findAll({
            where: { userId: user.id },
            include: [
                {
                    model: StoryHighlightItem,
                    as: 'items',
                    limit: 1,
                    order: [['order', 'ASC']],
                },
            ],
            order: [['createdAt', 'DESC']],
        });

        return successResponse(
            res,
            'Highlights loaded',
            highlights.map(_formatHighlight)
        );
    } catch (error) {
        console.error('❌ getUserHighlights error:', error);
        return errorResponse(res, 'Failed to load highlights', 500);
    }
};

// ─────────────────────────────────────────────────────
// HIGHLIGHTS — GET SINGLE HIGHLIGHT + ITEMS
// GET /api/highlights/:highlightId
// ─────────────────────────────────────────────────────
const getHighlight = async (req, res) => {
    try {
        const { highlightId } = req.params;

        const highlight = await StoryHighlight.findByPk(highlightId, {
            include: [
                {
                    model: StoryHighlightItem,
                    as: 'items',
                    order: [['order', 'ASC']],
                },
                {
                    model: User,
                    as: 'user',
                    attributes: ['id', 'username', 'profilePicture'],
                },
            ],
        });

        if (!highlight) {
            return errorResponse(res, 'Highlight not found', 404);
        }

        return successResponse(
            res,
            'Highlight loaded',
            _formatHighlight(highlight)
        );
    } catch (error) {
        console.error('❌ getHighlight error:', error);
        return errorResponse(res, 'Failed to load highlight', 500);
    }
};

// ─────────────────────────────────────────────────────
// HIGHLIGHTS — UPDATE (rename / change cover)
// PUT /api/highlights/:highlightId
// body: { title?, coverUrl? }
// ─────────────────────────────────────────────────────
const updateHighlight = async (req, res) => {
    try {
        const { highlightId } = req.params;
        const userId = req.user.id;
        const { title, coverUrl } = req.body;

        const highlight = await StoryHighlight.findOne({
            where: { id: highlightId, userId },
        });
        if (!highlight) {
            return errorResponse(res, 'Highlight not found or not yours', 404);
        }

        const updates = {};
        if (title !== undefined) {
            if (title.trim().length === 0) {
                return errorResponse(res, 'Title cannot be empty', 400);
            }
            updates.title = title.trim().slice(0, 50);
        }
        if (coverUrl !== undefined) updates.coverUrl = coverUrl;

        await highlight.update(updates);

        return successResponse(
            res,
            'Highlight updated',
            _formatHighlight(highlight)
        );
    } catch (error) {
        console.error('❌ updateHighlight error:', error);
        return errorResponse(res, 'Failed to update highlight', 500);
    }
};

// ─────────────────────────────────────────────────────
// HIGHLIGHTS — DELETE
// DELETE /api/highlights/:highlightId
// ─────────────────────────────────────────────────────
const deleteHighlight = async (req, res) => {
    try {
        const { highlightId } = req.params;
        const userId = req.user.id;

        const highlight = await StoryHighlight.findOne({
            where: { id: highlightId, userId },
        });
        if (!highlight) {
            return errorResponse(res, 'Highlight not found or not yours', 404);
        }

        await highlight.destroy();
        return successResponse(res, 'Highlight deleted');
    } catch (error) {
        console.error('❌ deleteHighlight error:', error);
        return errorResponse(res, 'Failed to delete highlight', 500);
    }
};

// ─────────────────────────────────────────────────────
// HIGHLIGHTS — ADD STORY
// POST /api/highlights/:highlightId/stories
// body: { storyId }
// ─────────────────────────────────────────────────────
const addStoryToHighlight = async (req, res) => {
    try {
        const { highlightId } = req.params;
        const userId = req.user.id;
        const { storyId } = req.body;

        // ─── Check highlight ownership ────────────────────
        const highlight = await StoryHighlight.findOne({
            where: { id: highlightId, userId },
        });
        if (!highlight) {
            return errorResponse(res, 'Highlight not found or not yours', 404);
        }

        // ─── Check story ownership ────────────────────────
        const story = await Story.findOne({
            where: { id: storyId, userId },
            attributes: ['id', 'mediaUrl', 'thumbnailUrl', 'mediaType'],
        });
        if (!story) {
            return errorResponse(res, 'Story not found or not yours', 404);
        }

        // ─── Check not already in highlight ───────────────
        const existing = await StoryHighlightItem.findOne({
            where: { highlightId, storyId },
        });
        if (existing) {
            return errorResponse(res, 'Story already in this highlight', 400);
        }

        // ─── Get current item count for order ────────────
        const count = await StoryHighlightItem.count({ where: { highlightId } });

        await StoryHighlightItem.create({
            id: uuidv4(),
            highlightId,
            storyId,
            storyUrl: story.mediaUrl,
            storyThumbnailUrl: story.thumbnailUrl,
            storyMediaType: story.mediaType || 'image',
            order: count,
        });

        // ─── Update count + cover if first item ──────────
        await highlight.increment('storiesCount');
        if (count === 0) {
            await highlight.update({
                coverUrl: story.thumbnailUrl || story.mediaUrl,
            });
        }

        return successResponse(res, 'Story added to highlight');
    } catch (error) {
        console.error('❌ addStoryToHighlight error:', error);
        return errorResponse(res, 'Failed to add story to highlight', 500);
    }
};

// ─────────────────────────────────────────────────────
// HIGHLIGHTS — REMOVE STORY
// DELETE /api/highlights/:highlightId/stories/:storyId
// ─────────────────────────────────────────────────────
const removeStoryFromHighlight = async (req, res) => {
    try {
        const { highlightId, storyId } = req.params;
        const userId = req.user.id;

        const highlight = await StoryHighlight.findOne({
            where: { id: highlightId, userId },
        });
        if (!highlight) {
            return errorResponse(res, 'Highlight not found or not yours', 404);
        }

        const item = await StoryHighlightItem.findOne({
            where: { highlightId, storyId },
        });
        if (!item) {
            return errorResponse(res, 'Story not in this highlight', 404);
        }

        await item.destroy();

        // ─── Decrement count ──────────────────────────────
        if (highlight.storiesCount > 0) {
            await highlight.decrement('storiesCount');
        }

        // ─── Update cover if removed item was the cover ───
        const firstItem = await StoryHighlightItem.findOne({
            where: { highlightId },
            order: [['order', 'ASC']],
        });
        if (firstItem) {
            await highlight.update({
                coverUrl: firstItem.storyThumbnailUrl || firstItem.storyUrl,
            });
        } else {
            await highlight.update({ coverUrl: null, storiesCount: 0 });
        }

        return successResponse(res, 'Story removed from highlight');
    } catch (error) {
        console.error('❌ removeStoryFromHighlight error:', error);
        return errorResponse(res, 'Failed to remove story', 500);
    }
};

// ─────────────────────────────────────────────────────
// PRIVATE HELPERS
// ─────────────────────────────────────────────────────

const _formatHighlight = (highlight) => ({
    id: highlight.id,
    userId: highlight.userId,
    title: highlight.title,
    coverUrl: highlight.coverUrl,
    storiesCount: highlight.storiesCount,
    createdAt: highlight.createdAt,
    items: (highlight.items || []).map((item) => ({
        id: item.id,
        storyId: item.storyId,
        storyUrl: item.storyUrl,
        thumbnailUrl: item.storyThumbnailUrl,
        mediaType: item.storyMediaType,
        order: item.order,
    })),
    user: highlight.user
        ? {
            id: highlight.user.id,
            username: highlight.user.username,
            profilePicture: highlight.user.profilePicture,
        }
        : undefined,
});

// ─── Find a direct (non-group) conversation between 2 users ───
const _findDmConversation = async (userAId, userBId) => {
    const { Op } = require('sequelize');

    // Find conversations where both users are participants
    // and it's not a group chat
    const participations = await ConversationParticipant.findAll({
        where: { userId: userAId },
        attributes: ['conversationId'],
    });

    const convIds = participations.map((p) => p.conversationId);
    if (!convIds.length) return null;

    const conversation = await Conversation.findOne({
        where: { id: { [Op.in]: convIds }, isGroup: false },
        include: [
            {
                model: ConversationParticipant,
                as: 'participants',
                where: { userId: userBId },
                required: true,
            },
        ],
    });

    return conversation;
};

module.exports = {
    votePoll,
    getPollResults,
    answerQuestion,
    getQuestionAnswers,
    reactToStory,
    removeReaction,
    replyToStory,
    createHighlight,
    getUserHighlights,
    getHighlight,
    updateHighlight,
    deleteHighlight,
    addStoryToHighlight,
    removeStoryFromHighlight,
};