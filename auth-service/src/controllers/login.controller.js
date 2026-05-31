// src/controllers/login.controller.js

const User = require('../models/User');
const { OtpService, OtpError } = require('../services/otp.service');
const emailService = require('../services/email.service');
const jwtService = require('../services/jwt.service');
const { success, error } = require('../utils/response.utils');
const logger = require('../utils/logger');

// ── Login with password ───────────────────────────────
async function login(req, res) {
  try {
    const emailOrUsername = req.body.emailOrUsername || req.body.identifier;
    const { password, deviceId, deviceName } = req.body;

    // Find user
    const isEmail = emailOrUsername.includes('@');
    const query = isEmail
      ? { email: emailOrUsername.toLowerCase() }
      : { username: emailOrUsername.toLowerCase() };

    let user = await User.findOne({
      ...query,
      deletedAt: null,
    }).select('+password');

    if (!user) {
      // User not in MongoDB. Try to sync them from the main backend (PostgreSQL) dynamically!
      try {
        const axios = require('axios');
        let backendUrl = process.env.MAIN_BACKEND_URL || 'https://instagram-clone-im0x.onrender.com';
        if (process.env.NODE_ENV === 'production' && (backendUrl.includes('localhost') || backendUrl.includes('127.0.0.1') || backendUrl.includes('3000'))) {
          backendUrl = 'https://instagram-clone-im0x.onrender.com';
        }

        let cleanUrl = backendUrl.trim();
        if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.slice(0, -1);
        if (!cleanUrl.endsWith('/api/v1')) cleanUrl = cleanUrl + '/api/v1';
        const targetUrl = `${cleanUrl}/internal/verify-existing-user`;

        const response = await axios.post(
          targetUrl,
          { emailOrUsername, password },
          {
            headers: {
              'x-service-secret': process.env.INTER_SERVICE_SECRET,
              'Content-Type': 'application/json',
            },
            timeout: 5000,
          }
        );

        if (response.data && response.data.success) {
          const verifiedData = response.data.data;
          // Dynamically create the user record in Mongoose so they are fully synced!
          user = await User.create({
            uuid: verifiedData.userId,
            email: verifiedData.email,
            username: verifiedData.username,
            fullName: verifiedData.fullName,
            password: verifiedData.passwordHash, // This will bypass hashing in Mongoose pre-save because it starts with bcrypt format!
            isEmailVerified: verifiedData.isEmailVerified,
            emailVerifiedAt: verifiedData.isEmailVerified ? new Date() : undefined,
            authProviders: [{ provider: 'email' }],
            registrationIp: req.ip,
          });
          logger.info(`👤 Dynamically synced user ${user.username} from Postgres to MongoDB on login`);
        }
      } catch (syncErr) {
        // If main backend returned 401 (invalid password) or 404 (not found), or connection fails:
        // Log it, then fail with INVALID_CREDENTIALS
        const status = syncErr.response?.status;
        if (status === 401) {
          return res.status(401).json(error(
            'INVALID_CREDENTIALS',
            'Incorrect email/username or password.'
          ));
        }
        logger.error(`Failed to sync existing user from main backend: ${syncErr.message}`);
      }

      if (!user) {
        return res.status(401).json(error(
          'INVALID_CREDENTIALS',
          'Incorrect email/username or password.'
        ));
      }
    }

    // Check if account is locked
    if (user.isLocked()) {
      const lockMinutes = Math.ceil(
        (user.lockUntil - Date.now()) / 60000
      );
      return res.status(423).json(error(
        'ACCOUNT_LOCKED',
        `Account locked due to too many failed attempts. Try again in ${lockMinutes} minute(s).`,
        { lockMinutes }
      ));
    }

    // Check if suspended
    if (user.isSuspended) {
      return res.status(403).json(error(
        'ACCOUNT_SUSPENDED',
        'This account has been suspended.',
        { reason: user.suspendedReason }
      ));
    }

    // Verify password
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      await user.incrementLoginAttempts();
      return res.status(401).json(error(
        'INVALID_CREDENTIALS',
        'Incorrect email/username or password.'
      ));
    }

    // Check email verification
    if (!user.isEmailVerified) {
      // Send new OTP
      const otp = await OtpService.createOtp(
        user.email, 'email_verify',
        { ip: req.ip, userAgent: req.get('User-Agent') }
      );
      emailService.sendOtpEmail({
        to: user.email,
        otp,
        type: 'email_verify',
        username: user.username,
      }).catch(err => logger.error(`Login verification email background send failed: ${err.message}`));

      return res.status(403).json(error(
        'EMAIL_NOT_VERIFIED',
        'Please verify your email first. A new code has been sent.',
        { email: user.email, nextStep: 'verify_email' }
      ));
    }

    // 2FA check
    if (user.twoFactorEnabled) {
      return res.status(200).json(success(
        'TWO_FACTOR_REQUIRED',
        'Please complete 2FA verification.',
        {
          userId: user._id,
          nextStep: 'two_factor',
          method: 'totp',
        }
      ));
    }

    // Reset failed attempts
    await user.resetLoginAttempts();

    // Update last login
    user.lastLoginIp = req.ip;
    user.lastLoginAt = new Date();
    await user.save();

    // Generate tokens
    const accessToken = jwtService.generateAccessToken({
      userId: user.uuid,
      mongoId: user._id,
      email: user.email,
      username: user.username,
      isEmailVerified: user.isEmailVerified,
    });
    const refreshToken = jwtService.generateRefreshToken();

    await jwtService.saveRefreshToken(user._id, refreshToken, {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      deviceId,
      deviceName,
    });

    return res.status(200).json(success(
      'LOGIN_SUCCESS',
      'Logged in successfully.',
      {
        user: {
          id: user.uuid,
          email: user.email,
          username: user.username,
          full_name: user.fullName,
          is_email_verified: user.isEmailVerified,
        },
        tokens: {
          accessToken,
          refreshToken,
          expiresIn: process.env.JWT_EXPIRES_IN || '7d',
        },
      }
    ));
  } catch (err) {
    if (err instanceof OtpError) {
      return res.status(429).json(error(err.code, err.message, err.data));
    }
    logger.error('Login error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Login failed.'));
  }
}

// ── Logout ────────────────────────────────────────────
async function logout(req, res) {
  try {
    const authHeader = req.headers.authorization;
    const { refreshToken } = req.body;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      const accessToken = authHeader.split(' ')[1];
      // Blacklist access token in Redis
      await jwtService.blacklistToken(accessToken);
    }

    if (refreshToken) {
      const RefreshToken = require('../models/RefreshToken');
      // Revoke refresh token in MongoDB
      await RefreshToken.findOneAndUpdate(
        { token: refreshToken },
        { isRevoked: true, revokedAt: new Date(), revokedReason: 'logout' }
      );
    }

    return res.status(200).json(success('LOGOUT_SUCCESS', 'Logged out successfully.'));
  } catch (err) {
    logger.error('Logout error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Logout failed.'));
  }
}

// ── Logout all devices ────────────────────────────────
async function logoutAll(req, res) {
  try {
    const userId = req.user._id;
    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      const accessToken = authHeader.split(' ')[1];
      await jwtService.blacklistToken(accessToken);
    }

    await jwtService.revokeAllTokens(userId);

    return res.status(200).json(success('LOGOUT_ALL_SUCCESS', 'Logged out from all devices.'));
  } catch (err) {
    logger.error('Logout all error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Failed to log out from all devices.'));
  }
}

module.exports = { login, logout, logoutAll };
