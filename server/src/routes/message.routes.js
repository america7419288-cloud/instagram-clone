// server/src/routes/message.routes.js
// Separate file for message-specific routes

const express = require('express');
const router = express.Router();

const {
  deleteMessage,
} = require('../controllers/conversation.controller');

const { protect } = require('../middleware/auth.middleware');

// DELETE /api/v1/messages/:id → unsend message
router.delete('/:id', protect, deleteMessage);

module.exports = router;