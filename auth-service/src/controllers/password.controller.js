// src/controllers/password.controller.js

const User = require('../models/User');
const { OtpService, OtpError } = require('../services/otp.service');
const emailService = require('../services/email.service');
const { getRedis } = require('../config/redis');
const { REDIS_KEYS } = require('../config/constants');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { success, error } = require('../utils/response.utils');
const logger = require('../utils/logger');

// ── Step 1: Request Password Reset (sends OTP) ────────
async function forgotPassword(req, res) {
  try {
    const { email } = req.body;

    const user = await User.findOne({ email: email.toLowerCase(), deletedAt: null });
    if (!user) {
      // Don't leak account existence, return a positive response
      return res.status(200).json(success(
        'RESET_OTP_SENT',
        'If the email is registered, a password reset code has been sent.',
        { email }
      ));
    }

    const otp = await OtpService.createOtp(user.email, 'password_reset', {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
    });

    await emailService.sendOtpEmail({
      to: user.email,
      otp,
      type: 'password_reset',
      username: user.username,
    });

    return res.status(200).json(success(
      'RESET_OTP_SENT',
      'A password reset verification code has been sent to your email.',
      { email }
    ));
  } catch (err) {
    if (err instanceof OtpError) {
      return res.status(429).json(error(err.code, err.message, err.data));
    }
    logger.error('Forgot password error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Failed to process request.'));
  }
}

// ── Step 2: Verify Password Reset OTP ─────────────────
async function verifyResetOtp(req, res) {
  try {
    const { email, otp } = req.body;

    // Verify OTP
    await OtpService.verifyOtp(email, otp, 'password_reset');

    // Create a temporary, secure reset token
    const resetToken = crypto.randomBytes(32).toString('hex');
    const redis = getRedis();

    // Store in Redis (valid for 15 minutes)
    const resetKey = `${REDIS_KEYS.RESET_TOKEN}${resetToken}`;
    await redis.setEx(resetKey, 15 * 60, email.toLowerCase().trim());

    return res.status(200).json(success(
      'OTP_VERIFIED',
      'Code verified successfully. You may now reset your password.',
      { resetToken }
    ));
  } catch (err) {
    if (err instanceof OtpError) {
      const statusMap = {
        OTP_EXPIRED: 410,
        INVALID_OTP: 400,
        MAX_ATTEMPTS_EXCEEDED: 429,
      };
      return res.status(statusMap[err.code] || 400).json(
        error(err.code, err.message, err.data)
      );
    }
    logger.error('Verify reset OTP error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Verification failed.'));
  }
}

// ── Step 3: Reset Password with Reset Token ───────────
async function resetPassword(req, res) {
  try {
    const { resetToken, newPassword } = req.body;

    if (!resetToken || !newPassword) {
      return res.status(400).json(error('BAD_REQUEST', 'Reset token and new password are required.'));
    }

    if (newPassword.length < 8) {
      return res.status(400).json(error('BAD_REQUEST', 'Password must be at least 8 characters.'));
    }

    const redis = getRedis();
    const resetKey = `${REDIS_KEYS.RESET_TOKEN}${resetToken}`;

    // Get email from token
    const email = await redis.get(resetKey);
    if (!email) {
      return res.status(400).json(error('INVALID_TOKEN', 'Reset token has expired or is invalid.'));
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json(error('USER_NOT_FOUND', 'User not found.'));
    }

    // Hash and save password
    user.password = newPassword;
    await user.save();

    // Delete token in Redis
    await redis.del(resetKey);

    // Sync to main backend
    await notifyMainBackend('password.changed', {
      userId: user.uuid,
      passwordHash: user.password,
    });

    // Notify user via email
    emailService.sendPasswordChangedEmail({
      to: user.email,
      username: user.username,
    }).catch(err => logger.error('Password changed notification email failed:', err));

    return res.status(200).json(success('PASSWORD_RESET_SUCCESS', 'Your password was successfully reset.'));
  } catch (err) {
    logger.error('Reset password error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Failed to reset password.'));
  }
}

// ── Change Password (when logged in) ──────────────────
async function changePassword(req, res) {
  try {
    const userId = req.user._id;
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json(error('BAD_REQUEST', 'Current password and new password are required.'));
    }

    const user = await User.findById(userId).select('+password');
    if (!user) {
      return res.status(404).json(error('USER_NOT_FOUND', 'User not found.'));
    }

    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(400).json(error('INVALID_PASSWORD', 'Your current password is incorrect.'));
    }

    user.password = newPassword;
    await user.save();

    // Sync to main backend
    await notifyMainBackend('password.changed', {
      userId: user.uuid,
      passwordHash: user.password,
    });

    emailService.sendPasswordChangedEmail({
      to: user.email,
      username: user.username,
    }).catch(err => logger.error('Password change email warning failed:', err));

    return res.status(200).json(success('PASSWORD_CHANGED', 'Password updated successfully.'));
  } catch (err) {
    logger.error('Change password error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Failed to update password.'));
  }
}

// ── Inter-service notification ─────────────────────────
async function notifyMainBackend(event, data) {
  try {
    const axios = require('axios');
    await axios.post(
      `${process.env.MAIN_BACKEND_URL}/internal/auth-events`,
      { event, data },
      {
        headers: {
          'x-service-secret': process.env.INTER_SERVICE_SECRET,
          'Content-Type': 'application/json',
        },
        timeout: 5000,
      }
    );
  } catch (err) {
    logger.error('Failed to notify main backend:', err.message);
  }
}

module.exports = { forgotPassword, verifyResetOtp, resetPassword, changePassword };
