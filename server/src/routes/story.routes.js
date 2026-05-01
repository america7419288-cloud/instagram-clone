// server/src/routes/story.routes.js

const express = require('express');
const router = express.Router();

const {
  createStory,
  getStoryFeed,
  getMyStories,
  getUserStories,
  viewStory,
  getStoryViewers,
  deleteStory,
  getStoryArchive,
} = require('../controllers/story.controller');

const { protect } = require('../middleware/auth.middleware');
const { uploadSingleImage } = require('../services/upload.service');

// ─── MULTER ERROR HANDLER ──────────────────────────────────
const handleUpload = (req, res, next) => {
  uploadSingleImage(req, res, (err) => {
    if (err) {
      return res.status(400).json({
        success: false,
        message: err.message || 'File upload error',
        timestamp: new Date().toISOString(),
      });
    }
    next();
  });
};

// ─── ROUTES ────────────────────────────────────────────────
// ⚠️ Specific routes BEFORE param routes

// GET story feed (from followed users)
router.get('/feed', protect, getStoryFeed);

// GET own stories
router.get('/my', protect, getMyStories);

// GET story archive (all own, including expired)
router.get('/archive', protect, getStoryArchive);

// GET stories by specific user
router.get('/user/:userId', protect, getUserStories);

// POST create story
router.post(
  '/',
  protect,
  handleUpload,
  createStory
);

// POST view a story
router.post('/:id/view', protect, viewStory);

// GET viewers of a story (owner only)
router.get('/:id/viewers', protect, getStoryViewers);

// DELETE own story
router.delete('/:id', protect, deleteStory);

module.exports = router;