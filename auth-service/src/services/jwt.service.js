// src/services/jwt.service.js

const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { getRedis } = require('../config/redis');
const RefreshToken = require('../models/RefreshToken');
const { REDIS_KEYS } = require('../config/constants');
const logger = require('../utils/logger');

class JwtService {
  // ── Generate access token (short-lived) ──────────────
  generateAccessToken(payload) {
    return jwt.sign(
      {
        sub: payload.userId, // User UUID
        id: payload.userId,  // User UUID (for main backend compat)
        _id: payload.mongoId, // MongoDB ObjectID
        email: payload.email,
        username: payload.username,
        verified: payload.isEmailVerified,
        iat: Math.floor(Date.now() / 1000),
      },
      process.env.JWT_ACCESS_SECRET || process.env.JWT_SECRET || 'your_super_secret_jwt_key_change_this',
      {
        expiresIn: process.env.JWT_ACCESS_EXPIRES || '15m',
        issuer: 'auth-service',
        audience: 'instagram-clone',
      }
    );
  }

  // ── Generate refresh token (long-lived) ──────────────
  generateRefreshToken() {
    return crypto.randomBytes(64).toString('hex');
  }

  // ── Save refresh token to DB ──────────────────────────
  async saveRefreshToken(userId, token, metadata = {}) {
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30); // 30 days

    await RefreshToken.create({
      userId,
      token,
      deviceId: metadata.deviceId,
      deviceName: metadata.deviceName,
      ipAddress: metadata.ip,
      userAgent: metadata.userAgent,
      expiresAt,
    });
  }

  // ── Verify access token ───────────────────────────────
  async verifyAccessToken(token) {
    try {
      // Check blacklist first
      const redis = getRedis();
      const isBlacklisted = await redis.get(
        `${REDIS_KEYS.BLACKLIST}${token}`
      );
      if (isBlacklisted) {
        throw new Error('TOKEN_BLACKLISTED');
      }

      const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET || process.env.JWT_SECRET || 'your_super_secret_jwt_key_change_this', {
        issuer: 'auth-service',
        audience: 'instagram-clone',
      });

      return { valid: true, decoded };
    } catch (error) {
      return { valid: false, error: error.message };
    }
  }

  // ── Verify and rotate refresh token ───────────────────
  async rotateRefreshToken(oldToken, metadata = {}) {
    // Find token in DB
    const tokenDoc = await RefreshToken.findOne({
      token: oldToken,
      isRevoked: false,
      expiresAt: { $gt: new Date() },
    }).populate('userId');

    if (!tokenDoc) {
      // Token reuse detected — revoke all tokens for this user
      const anyToken = await RefreshToken.findOne({ token: oldToken });
      if (anyToken) {
        await RefreshToken.updateMany(
          { userId: anyToken.userId },
          { isRevoked: true, revokedReason: 'token_reuse', revokedAt: new Date() }
        );
        logger.warn(`Token reuse detected for user ${anyToken.userId}`);
      }
      throw new Error('INVALID_REFRESH_TOKEN');
    }

    // Revoke old token
    tokenDoc.isRevoked = true;
    tokenDoc.revokedAt = new Date();
    tokenDoc.revokedReason = 'rotated';
    await tokenDoc.save();

    // Generate new tokens
    const user = tokenDoc.userId;
    const newAccessToken = this.generateAccessToken({
      userId: user.uuid,
      mongoId: user._id,
      email: user.email,
      username: user.username,
      isEmailVerified: user.isEmailVerified,
    });
    const newRefreshToken = this.generateRefreshToken();

    // Save new refresh token
    await this.saveRefreshToken(user._id, newRefreshToken, metadata);

    // Update last used
    tokenDoc.lastUsedAt = new Date();
    await tokenDoc.save();

    return {
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
      user,
    };
  }

  // ── Blacklist access token (logout) ───────────────────
  async blacklistToken(token) {
    try {
      const redis = getRedis();
      const decoded = jwt.decode(token);
      if (!decoded) return;

      const ttl = decoded.exp - Math.floor(Date.now() / 1000);
      if (ttl > 0) {
        await redis.setEx(
          `${REDIS_KEYS.BLACKLIST}${token}`,
          ttl,
          '1'
        );
      }
    } catch (error) {
      logger.error('Failed to blacklist token:', error.message);
    }
  }

  // ── Revoke all refresh tokens (logout all devices) ────
  async revokeAllTokens(userId) {
    await RefreshToken.updateMany(
      { userId, isRevoked: false },
      { isRevoked: true, revokedReason: 'logout_all', revokedAt: new Date() }
    );
  }

  // ── Get user's active sessions ─────────────────────────
  async getActiveSessions(userId) {
    return RefreshToken.find({
      userId,
      isRevoked: false,
      expiresAt: { $gt: new Date() },
    }).select('-token').sort({ lastUsedAt: -1 });
  }
}

module.exports = new JwtService();
