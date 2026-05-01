// server/src/routes/notification.routes.js

const express = require('express');
const router = express.Router();

const {
  getNotifications,
  getUnreadCount,
  markAllAsRead,
  markAsRead,
  deleteNotification,
  deleteAllNotifications,
} = require('../controllers/notification.controller');

const { protect } = require('../middleware/auth.middleware');

// ─── ROUTES ────────────────────────────────────────────────
// ⚠️ Specific routes BEFORE param routes

// GET all notifications (paginated)
router.get('/', protect, getNotifications);

// GET unread count (for badge)
router.get('/unread-count', protect, getUnreadCount);

// PUT mark ALL as read
router.put('/read-all', protect, markAllAsRead);

// DELETE all notifications
router.delete('/', protect, deleteAllNotifications);

// PUT mark ONE as read
router.put('/:id/read', protect, markAsRead);

// DELETE one notification
router.delete('/:id', protect, deleteNotification);

module.exports = router;