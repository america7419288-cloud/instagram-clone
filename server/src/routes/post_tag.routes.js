// server/src/routes/post_tag.routes.js

const express = require('express');
const router  = express.Router();

const {
  addTags,
  getPostTags,
  removeTag,
  acceptTag,
} = require('../controllers/post_tag.controller');

const {
  protect,
  optionalAuth,
} = require('../middleware/auth.middleware');

// ─── Post tag routes ──────────────────────────────────
// POST   /api/posts/:postId/tags        → add tags
// GET    /api/posts/:postId/tags        → get tags
// DELETE /api/posts/:postId/tags/:userId → remove one tag

router.post(  '/:postId/tags',           protect,      addTags);
router.get(   '/:postId/tags',           optionalAuth, getPostTags);
router.patch( '/:postId/tags/accept',    protect,      acceptTag);
router.delete('/:postId/tags/:userId',   protect,      removeTag);

module.exports = router;
