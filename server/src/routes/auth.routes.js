const express = require('express');
const router = express.Router();
const {
  register,
  login,
  getMe,
  logout,
  refreshToken,
  checkUsername,
  checkEmail,
} = require('../controllers/auth.controller');
const { protect } = require('../middleware/auth.middleware');
const {
  registerValidation,
  loginValidation,
  refreshTokenValidation,
  handleValidationErrors,
} = require('../validators/auth.validator');
router.post(
  '/register',
  registerValidation,
  handleValidationErrors,
  register
);
router.post(
  '/login',
  loginValidation,
  handleValidationErrors,
  login
);
router.post(
  '/refresh-token',
  refreshTokenValidation,
  handleValidationErrors,
  refreshToken
);
router.post(
  '/change-password',
  protect,
  async (req, res) => {
    try {
      const { current_password, new_password } = req.body;
      const userId = req.user.id;

      // Validate
      if (!current_password || !new_password) {
        return res.status(400).json({
          success: false,
          message: 'Both current and new password are required.',
        });
      }

      if (new_password.length < 8) {
        return res.status(400).json({
          success: false,
          message: 'New password must be at least 8 characters.',
        });
      }

      // Get user with password
      const { User } = require('../models');
      const { comparePassword, hashPassword } =
        require('../utils/password.utils');
      const { successResponse, errorResponse } =
        require('../utils/response.utils');

      const user = await User.scope('withPassword').findByPk(userId);

      if (!user || !user.password_hash) {
        return errorResponse(res, 400, 'Cannot change password for this account.');
      }

      // Verify current password
      const isCorrect = await comparePassword(
        current_password,
        user.password_hash
      );

      if (!isCorrect) {
        return errorResponse(res, 400, 'Current password is incorrect.');
      }

      // Check new password is different
      if (current_password === new_password) {
        return errorResponse(
          res,
          400,
          'New password must be different from current password.'
        );
      }

      // Hash and save new password
      const newHash = await hashPassword(new_password);
      await user.update({ password_hash: newHash });

      return successResponse(
        res,
        200,
        'Password changed successfully! ✅',
        {}
      );

    } catch (error) {
      console.error('❌ Change password error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to change password.',
      });
    }
  }
);
router.get('/check-username/:username', checkUsername);
router.get('/check-email/:email', checkEmail);
router.get('/me', protect, getMe);
router.post('/logout', protect, logout);

module.exports = router;