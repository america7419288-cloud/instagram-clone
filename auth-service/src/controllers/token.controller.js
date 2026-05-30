// src/controllers/token.controller.js

const jwtService = require('../services/jwt.service');
const RefreshToken = require('../models/RefreshToken');
const { success, error } = require('../utils/response.utils');
const logger = require('../utils/logger');

// ── Rotate refresh token ──────────────────────────────
async function refresh(req, res) {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json(error('BAD_REQUEST', 'Refresh token is required.'));
    }

    const metadata = {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      deviceId: req.body.deviceId,
      deviceName: req.body.deviceName,
    };

    const rotated = await jwtService.rotateRefreshToken(refreshToken, metadata);

    return res.status(200).json(success(
      'TOKEN_REFRESHED',
      'Token rotated successfully.',
      {
        user: {
          id: rotated.user.uuid,
          email: rotated.user.email,
          username: rotated.user.username,
          full_name: rotated.user.fullName,
          is_email_verified: rotated.user.isEmailVerified,
        },
        tokens: {
          accessToken: rotated.accessToken,
          refreshToken: rotated.refreshToken,
          expiresIn: '7d',
        },
      }
    ));
  } catch (err) {
    if (err.message === 'INVALID_REFRESH_TOKEN') {
      return res.status(401).json(error('INVALID_TOKEN', 'Refresh token is invalid or expired.'));
    }
    logger.error('Token refresh error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Failed to refresh token.'));
  }
}

// ── List active sessions ──────────────────────────────
async function getSessions(req, res) {
  try {
    const userId = req.user._id;
    const sessions = await jwtService.getActiveSessions(userId);

    return res.status(200).json(success('SESSIONS', 'Active sessions retrieved.', sessions));
  } catch (err) {
    logger.error('Get active sessions error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Failed to retrieve active sessions.'));
  }
}

// ── Revoke specific device session ────────────────────
async function revokeSession(req, res) {
  try {
    const userId = req.user._id;
    const { sessionId } = req.params;

    if (!sessionId) {
      return res.status(400).json(error('BAD_REQUEST', 'Session ID is required.'));
    }

    const session = await RefreshToken.findOne({ _id: sessionId, userId });
    if (!session) {
      return res.status(404).json(error('SESSION_NOT_FOUND', 'Active session not found.'));
    }

    session.isRevoked = true;
    session.revokedAt = new Date();
    session.revokedReason = 'manual_revocation';
    await session.save();

    return res.status(200).json(success('SESSION_REVOKED', 'Session revoked successfully.'));
  } catch (err) {
    logger.error('Revoke session error:', err);
    return res.status(500).json(error('SERVER_ERROR', 'Failed to revoke session.'));
  }
}

module.exports = { refresh, getSessions, revokeSession };
