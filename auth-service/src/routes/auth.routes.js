// src/routes/auth.routes.js

const express = require('express');
const router = express.Router();
const registerCtrl = require('../controllers/register.controller');
const loginCtrl = require('../controllers/login.controller');
const otpCtrl = require('../controllers/otp.controller');
const passwordCtrl = require('../controllers/password.controller');
const tokenCtrl = require('../controllers/token.controller');

const { protect } = require('../middleware/auth.middleware');
const { strictRateLimiter } = require('../middleware/rate-limit.middleware');
const {
  validateRegister,
  validateLogin,
  validateVerifyEmail,
  validateForgotPassword,
  validateVerifyResetOtp,
  validateResetPassword,
  validateChangePassword,
  validateRefresh,
  validateSendOtp,
  validateVerifyOtp,
  checkValidation,
} = require('../middleware/validate.middleware');

// ── Registration ──────────────────────────────────────
router.post('/register', strictRateLimiter, validateRegister, checkValidation, registerCtrl.register);
router.post('/verify-email', strictRateLimiter, validateVerifyEmail, checkValidation, registerCtrl.verifyEmail);
router.post('/resend-otp', strictRateLimiter, registerCtrl.resendOtp);

// ── Login & Sessions ──────────────────────────────────
router.post('/login', strictRateLimiter, validateLogin, checkValidation, loginCtrl.login);
router.post('/refresh-token', validateRefresh, checkValidation, tokenCtrl.refresh);
router.post('/logout', loginCtrl.logout);
router.post('/logout-all', protect, loginCtrl.logoutAll);
router.get('/sessions', protect, tokenCtrl.getSessions);
router.delete('/sessions/:sessionId', protect, tokenCtrl.revokeSession);

// ── OTPs ──────────────────────────────────────────────
router.post('/otp/send', strictRateLimiter, validateSendOtp, checkValidation, otpCtrl.sendOtp);
router.post('/otp/verify', strictRateLimiter, validateVerifyOtp, checkValidation, otpCtrl.verifyOtp);
router.get('/otp/status', otpCtrl.getStatus);

// ── Password Management ───────────────────────────────
router.post('/forgot-password', strictRateLimiter, validateForgotPassword, checkValidation, passwordCtrl.forgotPassword);
router.post('/verify-reset-otp', strictRateLimiter, validateVerifyResetOtp, checkValidation, passwordCtrl.verifyResetOtp);
router.post('/reset-password', strictRateLimiter, validateResetPassword, checkValidation, passwordCtrl.resetPassword);
router.post('/change-password', protect, validateChangePassword, checkValidation, passwordCtrl.changePassword);

module.exports = router;
