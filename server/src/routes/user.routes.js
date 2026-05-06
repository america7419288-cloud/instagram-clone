// server/src/routes/user.routes.js
// COMPLETE UPDATED FILE with follow endpoints

const express = require('express');
const router = express.Router();

// Controllers
const {
  getUserProfile,
  updateProfile,
  updateProfilePicture,
  removeProfilePicture,
  searchUsers,
  getSuggestedUsers,
  getUserById,
  saveFcmToken,
  clearFcmToken,
} = require('../controllers/user.controller');

const {
  followUser,
  unfollowUser,
  getFollowStatus,
  getFollowers,
  getFollowing,
  removeFollower,
  getFollowRequests,
  acceptFollowRequest,
  rejectFollowRequest,
} = require('../controllers/follow.controller');

// Middleware
const { protect, optionalAuth } = require('../middleware/auth.middleware');
const { uploadProfilePicture } = require('../services/upload.service');

// Validators
const {
  updateProfileValidation,
  searchValidation,
  handleValidationErrors,
} = require('../validators/user.validator');

// ─── MULTER HANDLER ────────────────────────────────────────
const handleUpload = (req, res, next) => {
  uploadProfilePicture.single('image')(req, res, (err) => {
    if (err) {
      return res.status(400).json({
        success: false,
        message: err.message || 'File upload error',
      });
    }
    next();
  });
};

// ─── ROUTES ────────────────────────────────────────────────
// ⚠️ SPECIFIC ROUTES BEFORE PARAM ROUTES

// Search users
router.get('/search', protect, searchValidation, handleValidationErrors, searchUsers);

// Suggested users
router.get('/suggestions', protect, getSuggestedUsers);

// ─── FCM Token endpoints ──────────────────────────────
router.put('/fcm-token', protect, saveFcmToken);
router.delete('/fcm-token', protect, clearFcmToken);

// ⭐ Follow requests (must be before /:id routes)
router.get('/follow-requests', protect, getFollowRequests);

// Edit own profile
router.put('/profile', protect, updateProfileValidation, handleValidationErrors, updateProfile);

// Profile picture
router.post('/profile-picture', protect, handleUpload, updateProfilePicture);
router.delete('/profile-picture', protect, removeProfilePicture);

// ─── USER SPECIFIC ROUTES (with :id param) ─────────────────

// Get user by UUID
router.get('/:id/basic', protect, getUserById);

// ⭐ Follow system
router.post('/:id/follow', protect, followUser);
router.delete('/:id/follow', protect, unfollowUser);
router.get('/:id/follow-status', protect, getFollowStatus);
router.get('/:id/followers', protect, getFollowers);
router.get('/:id/following', protect, getFollowing);
router.delete('/:id/follower', protect, removeFollower);
router.post('/:id/follow/accept', protect, acceptFollowRequest);
router.post('/:id/follow/reject', protect, rejectFollowRequest);

// Get user profile by username (must be LAST - catches everything)
router.get('/:username', optionalAuth, getUserProfile);

const { getUserHighlights } = require('../controllers/story_advanced.controller');

// ─── User highlights (NEW) ─────────────────────────────────
router.get('/:username/highlights', optionalAuth, getUserHighlights);

module.exports = router;