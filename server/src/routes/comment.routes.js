// server/src/routes/comment.routes.js

const express = require('express');
const router = express.Router();

const {
  addComment,
  getComments,
  getReplies,
  editComment,
  deleteComment,
  likeComment,
  unlikeComment,
  pinComment,
} = require('../controllers/comment.controller');

const { protect } = require('../middleware/auth.middleware');

// ─── POST COMMENT ROUTES ────────────────────────────────────
// These are mounted on /api/v1/posts/:postId/comments
// But defined here for organization

// Add comment to post: POST /api/v1/posts/:id/comments
// Get comments for post: GET /api/v1/posts/:id/comments
// (These are registered in post.routes.js - see below)

// ─── COMMENT ROUTES ─────────────────────────────────────────
// These are mounted on /api/v1/comments

// GET replies for a comment
router.get('/:id/replies', protect, getReplies);

// Edit comment
router.put('/:id', protect, editComment);

// Delete comment
router.delete('/:id', protect, deleteComment);

// Like / Unlike comment
router.post('/:id/like', protect, likeComment);
router.delete('/:id/like', protect, unlikeComment);

// Pin comment (post owner only)
router.post('/:id/pin', protect, pinComment);

module.exports = router;