// src/controllers/register.controller.js

const User = require('../models/User');
const { OtpService, OtpError } = require('../services/otp.service');
const emailService = require('../services/email.service');
const jwtService = require('../services/jwt.service');
const { success, error } = require('../utils/response.utils');
const logger = require('../utils/logger');

// ── Step 1: Register (sends OTP) ──────────────────────
async function register(req, res) {
  try {
    const { email, username, password, fullName } = req.body;

    // Check if email exists
    const existingEmail = await User.findOne({
      email: email.toLowerCase(),
      deletedAt: null,
    });

    if (existingEmail) {
      if (existingEmail.isEmailVerified) {
        return res.status(409).json(error(
          'EMAIL_TAKEN',
          'An account with this email already exists.'
        ));
      }

      // Email exists but not verified — resend OTP
      const otp = await OtpService.createOtp(
        email,
        'email_verify',
        { ip: req.ip, userAgent: req.get('User-Agent') }
      );

      await emailService.sendOtpEmail({
        to: email,
        otp,
        type: 'email_verify',
        username: existingEmail.username,
      });

      return res.status(200).json(success(
        'OTP_RESENT',
        'A new verification code was sent to your email.',
        { email, nextStep: 'verify_email' }
      ));
    }

    // Check username
    const existingUsername = await User.findOne({
      username: username.toLowerCase(),
    });
    if (existingUsername) {
      return res.status(409).json(error(
        'USERNAME_TAKEN',
        'This username is already taken.'
      ));
    }

    // Create unverified user
    const user = await User.create({
      email: email.toLowerCase(),
      username: username.toLowerCase(),
      fullName,
      password,
      authProviders: [{ provider: 'email' }],
      registrationIp: req.ip,
    });

    // Generate and send OTP
    const otp = await OtpService.createOtp(
      email,
      'email_verify',
      { ip: req.ip, userAgent: req.get('User-Agent') }
    );

    await emailService.sendOtpEmail({
      to: email,
      otp,
      type: 'email_verify',
      username,
    });

    logger.info(`New user registered: ${email}`);

    return res.status(201).json(success(
      'REGISTRATION_STARTED',
      'Account created. Please verify your email.',
      {
        email,
        username: user.username,
        nextStep: 'verify_email',
      }
    ));
  } catch (err) {
    if (err instanceof OtpError) {
      return res.status(429).json(error(err.code, err.message, err.data));
    }
    logger.error('Register error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Registration failed.'));
  }
}

// ── Step 2: Verify email OTP ──────────────────────────
async function verifyEmail(req, res) {
  try {
    const { email, otp } = req.body;

    // Verify OTP
    await OtpService.verifyOtp(email, otp, 'email_verify');

    // Mark user as verified
    const user = await User.findOneAndUpdate(
      { email: email.toLowerCase() },
      {
        isEmailVerified: true,
        emailVerifiedAt: new Date(),
      },
      { new: true }
    );

    if (!user) {
      return res.status(404).json(error('USER_NOT_FOUND', 'User not found.'));
    }

    // Generate tokens
    const accessToken = jwtService.generateAccessToken({
      userId: user.uuid,
      mongoId: user._id,
      email: user.email,
      username: user.username,
      isEmailVerified: true,
    });
    const refreshToken = jwtService.generateRefreshToken();

    await jwtService.saveRefreshToken(user._id, refreshToken, {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      deviceId: req.body.deviceId,
    });

    // Send welcome email (async — don't wait)
    emailService.sendWelcomeEmail({
      to: user.email,
      username: user.username,
    }).catch(err => logger.error('Welcome email failed:', err));

    // Notify main backend (inter-service)
    await notifyMainBackend('user.verified', {
      userId: user.uuid,
      email: user.email,
      username: user.username,
      fullName: user.fullName,
      passwordHash: user.password,
    });

    return res.status(200).json(success(
      'EMAIL_VERIFIED',
      'Email verified successfully!',
      {
        user: {
          id: user.uuid,
          email: user.email,
          username: user.username,
          full_name: user.fullName,
          is_email_verified: true,
        },
        tokens: {
          accessToken,
          refreshToken,
          expiresIn: '7d',
        },
      }
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
    logger.error('Verify email error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Verification failed.'));
  }
}

// ── Resend OTP ────────────────────────────────────────
async function resendOtp(req, res) {
  try {
    const { email, type = 'email_verify' } = req.body;

    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) {
      // Don't reveal if email exists
      return res.status(200).json(success(
        'OTP_SENT',
        'If an account exists, a code was sent.'
      ));
    }

    if (type === 'email_verify' && user.isEmailVerified) {
      return res.status(400).json(error(
        'ALREADY_VERIFIED',
        'Email is already verified.'
      ));
    }

    const otp = await OtpService.createOtp(email, type, {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
    });

    await emailService.sendOtpEmail({
      to: email,
      otp,
      type,
      username: user.username,
    });

    const status = await OtpService.getOtpStatus(email, type);

    return res.status(200).json(success(
      'OTP_SENT',
      'Verification code sent to your email.',
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
    logger.error('Resend OTP error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Failed to send OTP.'));
  }
}

// ── OTP Status ────────────────────────────────────────
async function getOtpStatus(req, res) {
  try {
    const { email, type = 'email_verify' } = req.query;
    const status = await OtpService.getOtpStatus(email, type);
    return res.status(200).json(success('STATUS', 'OTP status', status));
  } catch (err) {
    return res.status(500).json(error('SERVER_ERROR', 'Failed to get status.'));
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
    // Don't throw — main backend notification is not critical
  }
}

module.exports = { register, verifyEmail, resendOtp, getOtpStatus, notifyMainBackend };
