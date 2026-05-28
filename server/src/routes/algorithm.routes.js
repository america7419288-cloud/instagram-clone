// server/src/routes/algorithm.routes.js

const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth.middleware');
const {
  logInteraction,
  getRankedFeed,
  getUserInterests,
} = require('../controllers/algorithm.controller');

// ─── Routes ───────────────────────────────────────────
router.post('/interact', protect, logInteraction);
router.get('/feed', protect, getRankedFeed);
router.get('/interests', protect, getUserInterests);

module.exports = router;
