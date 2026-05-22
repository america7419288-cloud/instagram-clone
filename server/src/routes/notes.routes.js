// server/src/routes/notes.routes.js

const express = require('express');
const router = express.Router();

const {
  createNote,
  getNotesFeed,
  deleteNote,
} = require('../controllers/notes.controller');

const { protect } = require('../middleware/auth.middleware');

// All notes endpoints are private and require user authentication
router.post('/', protect, createNote);
router.get('/feed', protect, getNotesFeed);
router.delete('/', protect, deleteNote);

module.exports = router;
