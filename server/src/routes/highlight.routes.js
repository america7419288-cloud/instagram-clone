// server/src/routes/highlight.routes.js

const express = require('express');
const router = express.Router();

const {
    createHighlight,
    getUserHighlights,
    getHighlight,
    updateHighlight,
    deleteHighlight,
    addStoryToHighlight,
    removeStoryFromHighlight,
} = require('../controllers/story_advanced.controller');

const { protect } = require('../middleware/auth.middleware');

router.use(protect);

// ─── Highlight CRUD ───────────────────────────────────
router.post('/', createHighlight);
router.get('/:id', getHighlight);
router.put('/:id', updateHighlight);
router.delete('/:id', deleteHighlight);

// ─── Stories in highlight ─────────────────────────────
router.post('/:id/stories', addStoryToHighlight);
router.delete('/:id/stories/:storyId', removeStoryFromHighlight);

// ─── Get user highlights (by username) ───────────────
// NOTE: this is mounted under /api/users/:username/highlights
// So we handle it in user routes or app.js

module.exports = router;