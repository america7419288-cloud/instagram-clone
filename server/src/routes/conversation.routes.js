// server/src/routes/conversation.routes.js

const express = require('express');
const router = express.Router();

const {
  createOrGetConversation,
  getInbox,
  getConversation,
  getMessages,
  sendMessage,
  markAsRead,
  getUnreadCount,
  leaveConversation,
} = require('../controllers/conversation.controller');

const { protect } = require('../middleware/auth.middleware');
const { uploadPostMedia } = require('../services/upload.service');

// ─── ROUTES ────────────────────────────────────────────────
// ⚠️ Specific routes BEFORE param routes

// GET unread count (for badge) - BEFORE /:id
router.get('/unread-count', protect, getUnreadCount);

// GET inbox (all conversations)
router.get('/', protect, getInbox);

// POST create or get DM
router.post('/', protect, createOrGetConversation);

// GET single conversation
router.get('/:id', protect, getConversation);

// DELETE leave/hide conversation
router.delete('/:id', protect, leaveConversation);

// GET messages in conversation
router.get('/:id/messages', protect, getMessages);

// POST send message — support optional media file upload
router.post('/:id/messages', protect, uploadPostMedia.single('media'), sendMessage);

// DELETE unsend a message (conversation-scoped URL used by the client)
router.delete('/:id/messages/:messageId', protect, deleteMessage);

// PUT mark as read
router.put('/:id/read', protect, markAsRead);

module.exports = router;