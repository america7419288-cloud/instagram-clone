// src/middleware/auth.middleware.js

const jwtService = require('../services/jwt.service');
const { error } = require('../utils/response.utils');

async function protect(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json(error('UNAUTHORIZED', 'Access token is required.'));
    }

    const token = authHeader.split(' ')[1];
    const verification = await jwtService.verifyAccessToken(token);

    if (!verification.valid) {
      if (verification.error === 'jwt expired') {
        return res.status(401).json(error('TOKEN_EXPIRED', 'Access token has expired.'));
      }
      return res.status(401).json(error('UNAUTHORIZED', 'Access token is invalid.'));
    }

    req.user = verification.decoded;
    next();
  } catch (err) {
    return res.status(500).json(error('SERVER_ERROR', 'Authentication failed.'));
  }
}

module.exports = { protect };
