// server/src/routes/music.routes.js
const express = require('express');
const router = express.Router();
const musicController = require('../controllers/music.controller');
const { protect } = require('../middleware/auth.middleware');

// All music routes are protected
router.use(protect);

router.get('/search', musicController.searchMusic);
router.get('/stream/:videoId', musicController.streamMusic);

module.exports = router;
