// server/src/routes/report.routes.js

const express = require('express');
const router = express.Router();

const { reportUser, reportMessage } = require('../controllers/report.controller');
const { protect } = require('../middleware/auth.middleware');

// All reporting endpoints require authentication
router.post('/user/:userId', protect, reportUser);
router.post('/message/:messageId', protect, reportMessage);

module.exports = router;
