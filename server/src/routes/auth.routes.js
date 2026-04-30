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
router.get('/check-username/:username', checkUsername);
router.get('/check-email/:email', checkEmail);
router.get('/me', protect, getMe);
router.post('/logout', protect, logout);

module.exports = router;