// src/controllers/register.controller.js

const User = require('../models/User');
const { getRedis } = require('../config/redis');
const { OtpService, OtpError } = require('../services/otp.service');
const emailService = require('../services/email.service');
const jwtService = require('../services/jwt.service');
const { success, error } = require('../utils/response.utils');
const logger = require('../utils/logger');

// ── Step 1: Register (sends OTP) ──────────────────────
async function register(req, res) {
  try {
    const { email, username, password, fullName, full_name } = req.body;
    const finalFullName = fullName || full_name;
    const normalizedEmail = email.toLowerCase().trim();
    const normalizedUsername = username.toLowerCase().trim();

    // Check if email exists
    const existingEmail = await User.findOne({
      email: normalizedEmail,
      deletedAt: null,
    });

    if (existingEmail) {
      return res.status(409).json(error(
        'EMAIL_TAKEN',
        'An account with this email already exists.'
      ));
    }

    // Check username
    const existingUsername = await User.findOne({
      username: normalizedUsername,
    });
    if (existingUsername) {
      return res.status(409).json(error(
        'USERNAME_TAKEN',
        'This username is already taken.'
      ));
    }

    const redis = getRedis();

    // Check if username is reserved in pending registrations
    const pendingUsernameKey = `pending-register-username:${normalizedUsername}`;
    const reservedByEmail = await redis.get(pendingUsernameKey);
    if (reservedByEmail && reservedByEmail.toLowerCase() !== normalizedEmail) {
      return res.status(409).json(error(
        'USERNAME_TAKEN',
        'This username is already taken or reserved.'
      ));
    }

    // Clean up old reserved username if this email is re-registering with a new username
    const pendingEmailKey = `pending-register-email:${normalizedEmail}`;
    const existingPending = await redis.get(pendingEmailKey);
    if (existingPending) {
      try {
        const parsed = JSON.parse(existingPending);
        if (parsed.username && parsed.username.toLowerCase() !== normalizedUsername) {
          await redis.del(`pending-register-username:${parsed.username.toLowerCase()}`);
        }
      } catch (_) {}
    }

    // Store pending registration details (expires in 15 minutes)
    const pendingData = {
      email: normalizedEmail,
      username: normalizedUsername,
      password,
      fullName: finalFullName,
    };

    await redis.setEx(pendingEmailKey, 15 * 60, JSON.stringify(pendingData));
    await redis.setEx(pendingUsernameKey, 15 * 60, normalizedEmail);

    // Generate and send OTP
    const otp = await OtpService.createOtp(
      normalizedEmail,
      'email_verify',
      { ip: req.ip, userAgent: req.get('User-Agent') }
    );

    emailService.sendOtpEmail({
      to: normalizedEmail,
      otp,
      type: 'email_verify',
      username: normalizedUsername,
    }).catch(err => logger.error(`Verify email background send failed: ${err.message}`));

    logger.info(`Pending registration started for: ${normalizedEmail}`);

    return res.status(201).json(success(
      'REGISTRATION_STARTED',
      'Verification code sent to your email.',
      {
        email: normalizedEmail,
        username: normalizedUsername,
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
    const normalizedEmail = email.toLowerCase().trim();

    const redis = getRedis();
    const pendingEmailKey = `pending-register-email:${normalizedEmail}`;
    const pendingRaw = await redis.get(pendingEmailKey);

    if (!pendingRaw) {
      return res.status(400).json(error(
        'REGISTRATION_EXPIRED',
        'Registration session has expired or does not exist. Please register again.'
      ));
    }

    const pendingData = JSON.parse(pendingRaw);

    // Verify availability in DB again in case of race conditions
    const existingEmail = await User.findOne({
      email: normalizedEmail,
      deletedAt: null,
    });
    if (existingEmail) {
      return res.status(409).json(error(
        'EMAIL_TAKEN',
        'An account with this email was registered in the meantime.'
      ));
    }

    const existingUsername = await User.findOne({
      username: pendingData.username.toLowerCase(),
    });
    if (existingUsername) {
      return res.status(409).json(error(
        'USERNAME_TAKEN',
        'This username was taken in the meantime.'
      ));
    }

    // Verify OTP
    await OtpService.verifyOtp(normalizedEmail, otp, 'email_verify');

    // OTP verified successfully — Create the actual user record now
    const user = await User.create({
      email: normalizedEmail,
      username: pendingData.username.toLowerCase(),
      fullName: pendingData.fullName,
      password: pendingData.password,
      isEmailVerified: true,
      emailVerifiedAt: new Date(),
      authProviders: [{ provider: 'email' }],
      registrationIp: req.ip,
    });

    // Clean up pending registration from cache
    await redis.del(pendingEmailKey);
    await redis.del(`pending-register-username:${pendingData.username.toLowerCase()}`);

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
      'Email verified and account registered successfully!',
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
    const normalizedEmail = email.toLowerCase().trim();
    let username = 'User';

    if (type === 'email_verify') {
      const redis = getRedis();
      const pendingRaw = await redis.get(`pending-register-email:${normalizedEmail}`);
      if (!pendingRaw) {
        // Return generic success to not leak email details
        return res.status(200).json(success(
          'OTP_SENT',
          'If an account exists, a code was sent.'
        ));
      }
      const pendingData = JSON.parse(pendingRaw);
      username = pendingData.username;
    } else {
      const user = await User.findOne({ email: normalizedEmail });
      if (!user) {
        // Return generic success to not leak email details
        return res.status(200).json(success(
          'OTP_SENT',
          'If an account exists, a code was sent.'
        ));
      }
      if (user.isEmailVerified) {
        return res.status(400).json(error(
          'ALREADY_VERIFIED',
          'Email is already verified.'
        ));
      }
      username = user.username;
    }

    const otp = await OtpService.createOtp(normalizedEmail, type, {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
    });

    emailService.sendOtpEmail({
      to: normalizedEmail,
      otp,
      type,
      username,
    }).catch(err => logger.error(`Resend OTP background send failed: ${err.message}`));

    const status = await OtpService.getOtpStatus(normalizedEmail, type);

    return res.status(200).json(success(
      'OTP_SENT',
      'Verification code sent to your email.',
      {
        email: normalizedEmail,
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
    let backendUrl = process.env.MAIN_BACKEND_URL || 'https://instagram-clone-im0x.onrender.com';
    if (process.env.NODE_ENV === 'production' && (backendUrl.includes('localhost') || backendUrl.includes('127.0.0.1') || backendUrl.includes('3000'))) {
      backendUrl = 'https://instagram-clone-im0x.onrender.com';
    }

    let cleanUrl = backendUrl.trim();
    if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.slice(0, -1);
    if (!cleanUrl.endsWith('/api/v1')) cleanUrl = cleanUrl + '/api/v1';
    const targetUrl = `${cleanUrl}/internal/auth-events`;

    await axios.post(
      targetUrl,
      { event, data },
      {
        headers: {
          'x-service-secret': process.env.INTER_SERVICE_SECRET || 'shared_secret_between_services',
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
