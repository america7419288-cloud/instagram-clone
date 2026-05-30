// src/middleware/rate-limit.middleware.js

const rateLimit = require('express-rate-limit');
const logger = require('../utils/logger');

let globalRateLimiter;
let strictRateLimiter;

const windowMs = parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000; // 15 mins
const maxRequests = parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100;

try {
  const { getRedis } = require('../config/redis');
  const RedisStore = require('rate-limit-redis').default;

  const redis = getRedis();

  globalRateLimiter = rateLimit({
    windowMs,
    max: maxRequests,
    standardHeaders: true,
    legacyHeaders: false,
    store: new RedisStore({
      sendCommand: (...args) => redis.sendCommand(args),
      prefix: 'rl:global:',
    }),
    message: {
      success: false,
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many requests from this IP, please try again later.',
    },
  });

  strictRateLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes window
    max: 15, // limit each IP to 15 strict requests per window
    standardHeaders: true,
    legacyHeaders: false,
    store: new RedisStore({
      sendCommand: (...args) => redis.sendCommand(args),
      prefix: 'rl:strict:',
    }),
    message: {
      success: false,
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many login or verification attempts. Please wait 15 minutes.',
    },
  });

  logger.info('✅ Rate limiting configured with Redis store');
} catch (err) {
  logger.warn('Redis rate limit store failed to initialize, falling back to local memory store:', err.message);

  // Fallback to default MemoryStore
  globalRateLimiter = rateLimit({
    windowMs,
    max: maxRequests,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      success: false,
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many requests from this IP, please try again later.',
    },
  });

  strictRateLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 15,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      success: false,
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many login or verification attempts. Please wait 15 minutes.',
    },
  });
}

module.exports = { globalRateLimiter, strictRateLimiter };
