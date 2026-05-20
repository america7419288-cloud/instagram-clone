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
            return errorResponse(res, 400, 'Option must be "a" or "b"');
        }

        // ─── Check story exists ───────────────────────────
        const story = await Story.findByPk(storyId, {
            attributes: ['id', 'userId', 'expiresAt'],
        });
        if (!story) return errorResponse(res, 404, 'Story not found');

        // ─── Check story has poll ─────────────────────────
        const poll = await StoryPoll.findOne({ where: { storyId } });
        if (!poll) return errorResponse(res, 404, 'This story has no poll');

        // ─── Check already voted ──────────────────────────
        const existingVote = await StoryPollVote.findOne({
            where: { storyId, userId },
        });
        if (existingVote) {
            return errorResponse(res, 400, 'You have already voted');
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

        return successResponse(res, 200, 'Vote recorded', {
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
        return errorResponse(res, 500, 'Failed to vote');
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
        if (!poll) return errorResponse(res, 404, 'No poll found for this story');

        // ─── Did current user vote? ───────────────────────
        const myVote = await StoryPollVote.findOne({
            where: { storyId, userId },
            attributes: ['option'],
        });

        const totalVotes = poll.votesA + poll.votesB;

        return successResponse(res, 200, 'Poll results loaded', {
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
        return errorResponse(res, 500, 'Failed to get poll results');
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
        if (!answer || !answer.trim()) {
            return errorResponse(res, 400, 'Answer cannot be empty');
        }
        if (answer.length > 500) {
            return errorResponse(res, 400, 'Answer too long (max 500 chars)');
        }

        // ─── Check story + question exist ─────────────────
        const story = await Story.findByPk(storyId, {
            attributes: ['id', 'userId'],
        });
        if (!story) return errorResponse(res, 404, 'Story not found');

        const question = await StoryQuestion.findOne({
            where: { storyId },
        });

        if (!question) {
            return errorResponse(res, 404, 'This story has no question sticker');
        }

        // ─── Check already answered ───────────────────────
        const existing = await StoryAnswer.findOne({
            where: { questionId: question.id, userId },
        });
        if (existing) {
            return errorResponse(res, 400, 'You have already answered this question');
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

        return successResponse(res, 201, 'Answer submitted', {
            id: newAnswer.id,
            answer: newAnswer.answer,
            createdAt: newAnswer.createdAt,
        });
    } catch (error) {
        console.error('❌ answerQuestion error:', error);
        return errorResponse(res, 500, 'Failed to submit answer');
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
        if (!story) return errorResponse(res, 404, 'Story not found');
        if (story.userId !== userId) {
            return errorResponse(res, 403, 'Not authorized');
        }

        const question = await StoryQuestion.findOne({ where: { storyId } });
        if (!question) {
            return errorResponse(res, 404, 'No question found');
        }

        const answers = await StoryAnswer.findAll({
            where: { questionId: question.id },
            include: [
                {
                    model: User,
                    as: 'user',
                    attributes: ['id', 'username', 'profile_pic_url', 'is_verified'],
                },
            ],
            order: [['createdAt', 'DESC']],
        });

        return successResponse(res, 200, 'Answers loaded', {
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
        return errorResponse(res, 500, 'Failed to get answers');
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
        if (!story) return errorResponse(res, 404, 'Story not found');

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
            200,
            created ? 'Reaction added' : 'Reaction updated',
            { emoji }
        );
    } catch (error) {
        console.error('❌ reactToStory error:', error);
        return errorResponse(res, 500, 'Failed to react to story');
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
            return errorResponse(res, 404, 'No reaction found');
        }

        await reaction.destroy();
        return successResponse(res, 200, 'Reaction removed');
    } catch (error) {
        console.error('❌ removeReaction error:', error);
        return errorResponse(res, 500, 'Failed to remove reaction');
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
            return errorResponse(res, 400, 'Message cannot be empty');
        }

        // ─── Get story + owner ────────────────────────────
        const story = await Story.findByPk(storyId, {
            attributes: ['id', 'user_id', 'media_url', 'media_type', 'thumbnail_url'],
        });
        if (!story) return errorResponse(res, 404, 'Story not found');

        const recipientId = story.userId;

        // ─── Can't reply to own story ─────────────────────
        if (recipientId === senderId) {
            return errorResponse(res, 400, 'Cannot reply to your own story');
        }

        // ─── Find or create DM conversation ──────────────
        let conversation = await _findDmConversation(senderId, recipientId);

        if (!conversation) {
            conversation = await Conversation.create({
                id: uuidv4(),
                is_group: false,
            });

            await ConversationParticipant.bulkCreate([
                { id: uuidv4(), conversationId: conversation.id, userId: senderId },
                { id: uuidv4(), conversationId: conversation.id, userId: recipientId },
            ]);
        }

        // ─── Create message with story context ────────────
        const newMessage = await Message.create({
            id: uuidv4(),
            conversation_id: conversation.id,
            sender_id: senderId,
            message_type: 'story',
            content: message.trim(),
            media_url: story.media_url,
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
            attributes: ['id', 'username', 'profile_pic_url'],
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

        return successResponse(res, 201, 'Reply sent', {
            conversationId: conversation.id,
            messageId: newMessage.id,
        });
    } catch (error) {
        console.error('❌ replyToStory error:', error);
        return errorResponse(res, 500, 'Failed to send reply');
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
            return errorResponse(res, 400, 'Highlight title is required');
        }
        if (title.trim().length > 50) {
            return errorResponse(res, 400, 'Title max 50 characters');
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
            201,
            'Highlight created',
            _formatHighlight(highlight)
        );
    } catch (error) {
        console.error('❌ createHighlight error:', error);
        return errorResponse(res, 500, 'Failed to create highlight');
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
        if (!user) return errorResponse(res, 404, 'User not found');

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
            200,
            'Highlights loaded',
            highlights.map(_formatHighlight)
        );
    } catch (error) {
        console.error('❌ getUserHighlights error:', error);
        return errorResponse(res, 500, 'Failed to load highlights');
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
                    attributes: ['id', 'username', 'profile_pic_url'],
                },
            ],
        });

        if (!highlight) {
            return errorResponse(res, 404, 'Highlight not found');
        }

        return successResponse(
            res,
            200,
            'Highlight loaded',
            _formatHighlight(highlight)
        );
    } catch (error) {
        console.error('❌ getHighlight error:', error);
        return errorResponse(res, 500, 'Failed to load highlight');
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
            return errorResponse(res, 404, 'Highlight not found or not yours');
        }

        const updates = {};
        if (title !== undefined) {
            if (title.trim().length === 0) {
                return errorResponse(res, 400, 'Title cannot be empty');
            }
            updates.title = title.trim().slice(0, 50);
        }
        if (coverUrl !== undefined) updates.coverUrl = coverUrl;

        await highlight.update(updates);

        return successResponse(
            res,
            200,
            'Highlight updated',
            _formatHighlight(highlight)
        );
    } catch (error) {
        console.error('❌ updateHighlight error:', error);
        return errorResponse(res, 500, 'Failed to update highlight');
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
            return errorResponse(res, 404, 'Highlight not found or not yours');
        }

        await highlight.destroy();
        return successResponse(res, 200, 'Highlight deleted');
    } catch (error) {
        console.error('❌ deleteHighlight error:', error);
        return errorResponse(res, 500, 'Failed to delete highlight');
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
            return errorResponse(res, 404, 'Highlight not found or not yours');
        }

        // ─── Check story ownership ────────────────────────
        const story = await Story.findOne({
            where: { id: storyId, userId },
            attributes: ['id', 'mediaUrl', 'thumbnailUrl', 'mediaType'],
        });
        if (!story) {
            return errorResponse(res, 404, 'Story not found or not yours');
        }

        // ─── Check not already in highlight ───────────────
        const existing = await StoryHighlightItem.findOne({
            where: { highlightId, storyId },
        });
        if (existing) {
            return errorResponse(res, 400, 'Story already in this highlight');
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

        return successResponse(res, 200, 'Story added to highlight');
    } catch (error) {
        console.error('❌ addStoryToHighlight error:', error);
        return errorResponse(res, 500, 'Failed to add story to highlight');
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
            return errorResponse(res, 404, 'Highlight not found or not yours');
        }

        const item = await StoryHighlightItem.findOne({
            where: { highlightId, storyId },
        });
        if (!item) {
            return errorResponse(res, 404, 'Story not in this highlight');
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

        return successResponse(res, 200, 'Story removed from highlight');
    } catch (error) {
        console.error('❌ removeStoryFromHighlight error:', error);
        return errorResponse(res, 500, 'Failed to remove story');
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