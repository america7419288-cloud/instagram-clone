// server/src/routes/user_tagged.routes.js

const express = require('express');
const router  = express.Router();

const { getTaggedPosts } = require('../controllers/post_tag.controller');
const { optionalAuth }   = require('../middleware/auth.middleware');

// GET /api/users/:username/tagged-posts
router.get('/:username/tagged-posts', optionalAuth, getTaggedPosts);

module.exports = router;
