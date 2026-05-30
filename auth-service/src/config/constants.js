// src/config/constants.js

module.exports = {
  // OTP
  OTP_LENGTH: parseInt(process.env.OTP_LENGTH) || 6,
  OTP_EXPIRES_MS: (parseInt(process.env.OTP_EXPIRES_MINUTES) || 10) * 60 * 1000,
  OTP_MAX_ATTEMPTS: parseInt(process.env.OTP_MAX_ATTEMPTS) || 5,
  OTP_RESEND_COOLDOWN_MS: (parseInt(process.env.OTP_RESEND_COOLDOWN_SECONDS) || 60) * 1000,
  OTP_DAILY_LIMIT: parseInt(process.env.OTP_DAILY_LIMIT) || 10,

  // JWT
  JWT_ACCESS_EXPIRES: process.env.JWT_ACCESS_EXPIRES || '15m',
  JWT_REFRESH_EXPIRES: process.env.JWT_REFRESH_EXPIRES || '30d',

  // Redis key prefixes
  REDIS_KEYS: {
    OTP: 'otp:',              // otp:{email}
    OTP_ATTEMPTS: 'otp_att:', // otp_att:{email}
    OTP_COOLDOWN: 'otp_cd:',  // otp_cd:{email}
    OTP_DAILY: 'otp_day:',   // otp_day:{email}
    BLACKLIST: 'bl:',         // bl:{token}
    RESET_TOKEN: 'rst:',      // rst:{token}
  },

  // OTP types
  OTP_TYPES: {
    EMAIL_VERIFY: 'email_verify',
    PASSWORD_RESET: 'password_reset',
    LOGIN: 'login',
    PHONE_VERIFY: 'phone_verify',
  },

  // HTTP status codes
  HTTP: {
    OK: 200,
    CREATED: 201,
    BAD_REQUEST: 400,
    UNAUTHORIZED: 401,
    FORBIDDEN: 403,
    NOT_FOUND: 404,
    CONFLICT: 409,
    TOO_MANY_REQUESTS: 429,
    SERVER_ERROR: 500,
  },
};
