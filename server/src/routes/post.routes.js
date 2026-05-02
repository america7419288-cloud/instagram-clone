// server/src/routes/post.routes.js

const express = require('express');
const router = express.Router();

const {
  createPost,
  getFeed,
  getExplorePosts,
  getPost,
  getUserPosts,
  updatePost,
  deletePost,
  likePost,
  unlikePost,
  getPostLikers,
  savePost,
  unsavePost,
  getSavedPosts,
  getPostsByHashtag,
} = require('../controllers/post.controller');

const { protect, optionalAuth } = require('../middleware/auth.middleware');
const { uploadPostMedia } = require('../services/upload.service');

// ─── Multer error handler ─────────────────────────────
const handleMulterError = (err, req, res, next) => {
  if (err) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        message: 'File too large. Maximum size is 100MB for videos and 10MB for images.',
        timestamp: new Date().toISOString(),
      });
    }
    if (err.code === 'LIMIT_FILE_COUNT') {
      return res.status(400).json({
        success: false,
        message: 'Too many files. Maximum 10 files per post.',
        timestamp: new Date().toISOString(),
      });
    }
    return res.status(400).json({
      success: false,
      message: err.message || 'File upload error',
      timestamp: new Date().toISOString(),
    });
  }
  next();
};

// ─── Routes ───────────────────────────────────────────

// Feed + Explore (specific routes BEFORE parameterized routes)
router.get('/feed', protect, getFeed);
router.get('/explore', protect, getExplorePosts);
router.get('/saved', protect, getSavedPosts);
router.get('/hashtag/:tag', optionalAuth, getPostsByHashtag);
router.get('/user/:username', optionalAuth, getUserPosts);

// Create post with media upload
// Field name: 'media' (array, up to 10 files)
router.post(
  '/',
  protect,
  (req, res, next) => {
    uploadPostMedia.array('media', 10)(req, res, (err) => {
      handleMulterError(err, req, res, next);
    });
  },
  createPost
);

// Single post CRUD
router.get('/:postId', optionalAuth, getPost);
router.put('/:postId', protect, updatePost);
router.delete('/:postId', protect, deletePost);

// Like endpoints
router.post('/:postId/like', protect, likePost);
router.delete('/:postId/like', protect, unlikePost);
router.get('/:postId/likes', optionalAuth, getPostLikers);

// Save endpoints
router.post('/:postId/save', protect, savePost);
router.delete('/:postId/save', protect, unsavePost);

module.exports = router;