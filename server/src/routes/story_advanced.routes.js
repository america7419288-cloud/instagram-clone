// server/src/routes/story_advanced.routes.js

const express = require('express');
const router = express.Router();

const {
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
} = require('../controllers/story_advanced.controller');

const { protect } = require('../middleware/auth.middleware');

// ─── All routes require auth ──────────────────────────
router.use(protect);

// ─── Poll endpoints ───────────────────────────────────
router.post('/:storyId/poll/vote', votePoll);
router.get('/:storyId/poll/results', getPollResults);

// ─── Question endpoints ───────────────────────────────
router.post('/:storyId/question/answer', answerQuestion);
router.get('/:storyId/question/answers', getQuestionAnswers);

// ─── Reaction endpoints ───────────────────────────────
router.post('/:storyId/react', reactToStory);
router.delete('/:storyId/react', removeReaction);

// ─── Story reply ──────────────────────────────────────
router.post('/:storyId/reply', replyToStory);

// ─── Highlight endpoints ──────────────────────────────
// (mounted at /api/highlights)
// These are exported for use in a separate router

module.exports = router;