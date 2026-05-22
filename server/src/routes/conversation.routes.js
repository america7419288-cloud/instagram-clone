// server/src/routes/conversation.routes.js

const express = require('express');
const router = express.Router();

const {
  createOrGetConversation,
  getInbox,
  getConversation,
  getMessages,
  sendMessage,
  deleteMessage,
  markAsRead,
  getUnreadCount,
  leaveConversation,
  debugConversation,
  editMessage,
  createGroupConversation,
  setDisappearingMessages,
  searchMessages,
  reactToMessage,
  acceptConversationRequest,
  rejectConversationRequest,
} = require('../controllers/conversation.controller');

const { protect } = require('../middleware/auth.middleware');
const { uploadPostMedia } = require('../services/upload.service');

// ─── ROUTES ────────────────────────────────────────────────
// ⚠️ Specific routes BEFORE param routes

// GET unread count (for badge) - BEFORE /:id
router.get('/unread-count', protect, getUnreadCount);

// DEBUG endpoint - check conversation and participant status
router.get('/:id/debug', protect, debugConversation);

// GET inbox (all conversations)
router.get('/', protect, getInbox);

// POST create or get DM conversation
router.post('/', protect, createOrGetConversation);

// POST create group conversation (MUST be registered before dynamic /:id to prevent param collision)
router.post('/group', protect, createGroupConversation);

// GET single conversation
router.get('/:id', protect, getConversation);

// DELETE leave/hide conversation
router.delete('/:id', protect, leaveConversation);

// GET messages in conversation
router.get('/:id/messages', protect, getMessages);

// GET search history of messages in conversation
router.get('/:id/search', protect, searchMessages);

// POST send message — support optional media file upload
router.post('/:id/messages', protect, uploadPostMedia.single('media'), sendMessage);

// PUT edit message content
router.put('/:id/messages/:messageId', protect, editMessage);

// DELETE unsend a message (conversation-scoped URL used by the client)
router.delete('/:id/messages/:messageId', protect, deleteMessage);

// PUT mark as read
router.put('/:id/read', protect, markAsRead);

// PUT disappearing messages duration
router.put('/:id/disappearing', protect, setDisappearingMessages);

// POST react to a message with an emoji (toggles on/off)
router.post('/:id/messages/:messageId/react', protect, reactToMessage);

// POST accept conversation request
router.post('/:id/accept', protect, acceptConversationRequest);

// POST reject conversation request
router.post('/:id/reject', protect, rejectConversationRequest);

module.exports = router;