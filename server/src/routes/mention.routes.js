// server/src/routes/mention.routes.js

const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth.middleware');
const {
  searchMentions,
  getMentionNotifications,
  markMentionRead
} = require('../controllers/mention.controller');

// Search users to mention (context-aware)
router.get('/search', protect, searchMentions);

// Get mention notifications for current user
router.get('/notifications', protect, getMentionNotifications);

// Mark mention notification as read
router.put('/notifications/:notificationId/read', protect, markMentionRead);

module.exports = router;
