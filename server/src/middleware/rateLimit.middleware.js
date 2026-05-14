const rateLimit = require('express-rate-limit');

// ─── GENERAL API LIMITER ──────────────────────────────────────
// Used for most standard API endpoints
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  limit: 300, // Limit each IP to 300 requests per window
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again after 15 minutes',
  },
  handler: (req, res, next, options) => {
    console.warn(`⚠️ Rate limit exceeded for IP ${req.ip} on ${req.originalUrl}`);
    res.status(options.statusCode).send(options.message);
  },
});

// ─── AUTH LIMITER ─────────────────────────────────────────────
// Stricter limits for registration and login to prevent brute force
const authLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  limit: 20, // Limit each IP to 20 auth requests per hour
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many authentication attempts, please try again after an hour',
  },
  handler: (req, res, next, options) => {
    console.warn(`🔒 Auth rate limit exceeded for IP ${req.ip} on ${req.originalUrl}`);
    res.status(options.statusCode).send(options.message);
  },
});

// ─── SENSITIVE OPERATIONS LIMITER ──────────────────────────────
// Very strict limits for things like password resets
const strictLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  limit: 5, // Limit each IP to 5 requests per hour
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many sensitive requests, please try again after an hour',
  },
  handler: (req, res, next, options) => {
    console.error(`🚨 STRICT rate limit exceeded for IP ${req.ip} on ${req.originalUrl}`);
    res.status(options.statusCode).send(options.message);
  },
});

module.exports = {
  apiLimiter,
  authLimiter,
  strictLimiter,
};
