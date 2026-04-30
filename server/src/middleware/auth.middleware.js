const { verifyAccessToken } = require('../utils/jwt.utils');
const { errorResponse } = require('../utils/response.utils');
const { User } = require('../models');

const protect = async (req, res, next) => {
  try {
    let token;

    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.split(' ')[1]; 
    }

    if (!token) {
      return errorResponse(
        res,
        401,
        'Access denied. No token provided. Please login first.'
      );
    }

    const decoded = verifyAccessToken(token);

    if (!decoded) {
      return errorResponse(
        res,
        401,
        'Invalid or expired token. Please login again.'
      );
    }

    const user = await User.findByPk(decoded.id);

    if (!user) {
      return errorResponse(
        res,
        401,
        'User no longer exists. Please create a new account.'
      );
    }

    if (!user.is_active) {
      return errorResponse(
        res,
        403,
        'Your account has been deactivated.'
      );
    }

    if (user.is_banned) {
      return errorResponse(
        res,
        403,
        'Your account has been suspended.'
      );
    }

    req.user = user;

    console.log(`🔐 Authenticated: ${user.username} (${user.id})`);

    next();

  } catch (error) {
    console.error('❌ Auth middleware error:', error);
    return errorResponse(res, 500, 'Authentication failed.');
  }
};

const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      const decoded = verifyAccessToken(token);

      if (decoded) {
        const user = await User.findByPk(decoded.id);
        if (user && user.is_active && !user.is_banned) {
          req.user = user; 
        }
      }
    }

    next();

  } catch (error) {
    next();
  }
};
const adminOnly = (req, res, next) => {
  if (!req.user || !req.user.is_verified) {
    return errorResponse(
      res,
      403,
      'Access denied. Admin only.'
    );
  }
  next();
};

module.exports = {
  protect,
  optionalAuth,
  adminOnly,
};