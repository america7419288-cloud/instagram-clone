// server/src/routes/gif.routes.js

const express = require('express');
const router = express.Router();

const { searchGifs } = require('../controllers/gif.controller');
const { protect } = require('../middleware/auth.middleware');

// All gif endpoints require authentication
router.get('/search', protect, searchGifs);

module.exports = router;
