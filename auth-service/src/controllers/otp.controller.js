// src/controllers/otp.controller.js

const { OtpService, OtpError } = require('../services/otp.service');
const emailService = require('../services/email.service');
const User = require('../models/User');
const { success, error } = require('../utils/response.utils');
const logger = require('../utils/logger');

// ── Send general OTP ──────────────────────────────────
async function sendOtp(req, res) {
  try {
    const { email, type } = req.body;

    if (!email || !type) {
      return res.status(400).json(error('BAD_REQUEST', 'Email and type are required.'));
    }

    const user = await User.findOne({ email: email.toLowerCase() });
    const username = user ? user.username : email.split('@')[0];

    const otp = await OtpService.createOtp(email, type, {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
    });

    await emailService.sendOtpEmail({
      to: email,
      otp,
      type,
      username,
    });

    const status = await OtpService.getOtpStatus(email, type);

    return res.status(200).json(success(
      'OTP_SENT',
      'Verification code sent.',
      {
        email,
        resendAfterSeconds: status.resendAfterSeconds,
        expiresInMinutes: Math.ceil(status.otpExpiresInSeconds / 60),
      }
    ));
  } catch (err) {
    if (err instanceof OtpError) {
      return res.status(429).json(error(err.code, err.message, err.data));
    }
    logger.error('Send OTP error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Failed to send OTP.'));
  }
}

// ── Verify general OTP ────────────────────────────────
async function verifyOtp(req, res) {
  try {
    const { email, otp, type } = req.body;

    if (!email || !otp || !type) {
      return res.status(400).json(error('BAD_REQUEST', 'Email, OTP, and type are required.'));
    }

    await OtpService.verifyOtp(email, otp, type);

    return res.status(200).json(success('OTP_VERIFIED', 'OTP verified successfully.'));
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
    logger.error('Verify OTP error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Failed to verify OTP.'));
  }
}

// ── Get OTP status ────────────────────────────────────
async function getStatus(req, res) {
  try {
    const { email, type } = req.query;

    if (!email || !type) {
      return res.status(400).json(error('BAD_REQUEST', 'Email and type are required as query parameters.'));
    }

    const status = await OtpService.getOtpStatus(email, type);
    return res.status(200).json(success('OTP_STATUS', 'OTP status retrieved.', status));
  } catch (err) {
    logger.error('Get OTP status error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Failed to get OTP status.'));
  }
}

module.exports = { sendOtp, verifyOtp, getStatus };
