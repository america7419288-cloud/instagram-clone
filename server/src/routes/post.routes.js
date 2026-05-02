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
const { addComment, getComments } = require('../controllers/comment.controller');

const { protect } = require('../middleware/auth.middleware');
const { uploadMultipleMedia } = require('../services/upload.service');

// ─── MULTER ERROR HANDLER ──────────────────────────────────
const handleUpload = (req, res, next) => {
  uploadMultipleMedia(req, res, (err) => {
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
// ⚠️ SPECIFIC ROUTES BEFORE PARAM ROUTES

// Feed
router.get('/feed', protect, getFeed);

// Explore
router.get('/explore', protect, getExplorePosts);

// Posts by hashtag
router.get('/hashtag/:tag', protect, getPostsByHashtag);

// Saved posts (must be before /:id)
router.get('/saved', protect, getSavedPosts);

// User posts
router.get('/user/:userId', protect, getUserPosts);

// Create post (multipart upload)
router.post('/', protect, handleUpload, createPost);

// Single post CRUD
router.get('/:id', protect, getPost);
router.put('/:id', protect, updatePost);
router.delete('/:id', protect, deletePost);

// Like/Unlike
router.post('/:id/like', protect, likePost);
router.delete('/:id/like', protect, unlikePost);
router.get('/:id/likes', protect, getPostLikers);

// Save/Unsave
router.post('/:id/save', protect, savePost);
router.delete('/:id/save', protect, unsavePost);

// Comments (Nested)
router.post('/:id/comments', protect, addComment);
router.get('/:id/comments', protect, getComments);

module.exports = router;