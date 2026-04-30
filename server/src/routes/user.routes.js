// server/src/routes/user.routes.js

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
} = require('../controllers/user.controller');

// Middleware
const {
  protect,
  optionalAuth,
} = require('../middleware/auth.middleware');

// Upload middleware
const {
  uploadSingleImage,
} = require('../services/upload.service');

// Validators
const {
  updateProfileValidation,
  searchValidation,
  handleValidationErrors,
} = require('../validators/user.validator');

// ─── ROUTES ────────────────────────────────────────────────

// ⚠️ ORDER MATTERS IN EXPRESS!
// Specific routes MUST come BEFORE parameter routes
// /search must come before /:username
// /suggestions must come before /:username
// /profile must come before /:username

// GET /api/v1/users/search?q=john
router.get(
  '/search',
  protect,
  searchValidation,
  handleValidationErrors,
  searchUsers
);

// GET /api/v1/users/suggestions
router.get(
  '/suggestions',
  protect,
  getSuggestedUsers
);

// PUT /api/v1/users/profile
router.put(
  '/profile',
  protect,
  updateProfileValidation,
  handleValidationErrors,
  updateProfile
);

// PUT /api/v1/users/profile-picture
// uploadSingleImage is multer middleware
// It processes the file before controller runs
router.put(
  '/profile-picture',
  protect,
  (req, res, next) => {
    // Handle multer errors gracefully
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
  },
  updateProfilePicture
);

// DELETE /api/v1/users/profile-picture
router.delete(
  '/profile-picture',
  protect,
  removeProfilePicture
);

// GET /api/v1/users/:id/basic
router.get(
  '/:id/basic',
  protect,
  getUserById
);

// GET /api/v1/users/:username
// optionalAuth: works for logged-in AND guest users
router.get(
  '/:username',
  optionalAuth,
  getUserProfile
);

module.exports = router;