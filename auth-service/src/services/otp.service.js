// src/services/otp.service.js

const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { getRedis } = require('../config/redis');
const OtpRecord = require('../models/OtpRecord');
const { REDIS_KEYS, OTP_TYPES } = require('../config/constants');
const logger = require('../utils/logger');

const OTP_LENGTH = parseInt(process.env.OTP_LENGTH) || 6;
const OTP_EXPIRES_MS = (parseInt(process.env.OTP_EXPIRES_MINUTES) || 10) * 60 * 1000;
const OTP_MAX_ATTEMPTS = parseInt(process.env.OTP_MAX_ATTEMPTS) || 5;
const OTP_RESEND_COOLDOWN_S = parseInt(process.env.OTP_RESEND_COOLDOWN_SECONDS) || 60;
const OTP_DAILY_LIMIT = parseInt(process.env.OTP_DAILY_LIMIT) || 10;

class OtpService {
  // ── Generate cryptographically secure OTP ─────────────
  generateOtp() {
    // Cryptographically secure random digits
    const buffer = crypto.randomBytes(4);
    const num = buffer.readUInt32BE(0);
    const otp = (num % Math.pow(10, OTP_LENGTH))
      .toString()
      .padStart(OTP_LENGTH, '0');
    return otp;
  }

  // ── Create and store OTP ──────────────────────────────
  async createOtp(email, type, metadata = {}) {
    const redis = getRedis();
    const normalizedEmail = email.toLowerCase().trim();

    // 1. Check daily limit
    const dailyKey = `${REDIS_KEYS.OTP_DAILY}${normalizedEmail}:${type}`;
    const dailyCount = await redis.get(dailyKey);
    if (parseInt(dailyCount || 0) >= OTP_DAILY_LIMIT) {
      throw new OtpError('DAILY_LIMIT_EXCEEDED',
        'Too many OTP requests today. Try again tomorrow.');
    }

    // 2. Check resend cooldown
    const cooldownKey = `${REDIS_KEYS.OTP_COOLDOWN}${normalizedEmail}:${type}`;
    const cooldownTtl = await redis.ttl(cooldownKey);
    if (cooldownTtl > 0) {
      throw new OtpError('RESEND_TOO_SOON',
        `Please wait ${cooldownTtl} seconds before requesting a new OTP.`,
        { waitSeconds: cooldownTtl });
    }

    // 3. Generate OTP
    const otp = this.generateOtp();

    // 4. Hash OTP for Redis storage
    const hashedOtp = await bcrypt.hash(otp, 10);

    // 5. Store in Redis with expiry
    const otpKey = `${REDIS_KEYS.OTP}${normalizedEmail}:${type}`;
    await redis.setEx(otpKey, Math.floor(OTP_EXPIRES_MS / 1000), hashedOtp);

    // 6. Reset attempts counter
    const attemptsKey = `${REDIS_KEYS.OTP_ATTEMPTS}${normalizedEmail}:${type}`;
    await redis.del(attemptsKey);

    // 7. Set cooldown
    await redis.setEx(cooldownKey, OTP_RESEND_COOLDOWN_S, '1');

    // 8. Increment daily counter
    const pipe = redis.multi();
    pipe.incr(dailyKey);
    pipe.expire(dailyKey, 24 * 60 * 60); // 24 hours
    await pipe.exec();

    // 9. Save audit record to MongoDB (hashed)
    await OtpRecord.create({
      email: normalizedEmail,
      type,
      hashedOtp,
      expiresAt: new Date(Date.now() + OTP_EXPIRES_MS),
      ipAddress: metadata.ip,
      userAgent: metadata.userAgent,
    });

    logger.info(`OTP created for ${normalizedEmail} [${type}]`);
    return otp; // Return plain OTP (to be sent via email/SMS)
  }

  // ── Verify OTP ────────────────────────────────────────
  async verifyOtp(email, otpInput, type) {
    const redis = getRedis();
    const normalizedEmail = email.toLowerCase().trim();

    const otpKey = `${REDIS_KEYS.OTP}${normalizedEmail}:${type}`;
    const attemptsKey = `${REDIS_KEYS.OTP_ATTEMPTS}${normalizedEmail}:${type}`;

    // 1. Check if OTP exists in Redis
    const hashedOtp = await redis.get(otpKey);
    if (!hashedOtp) {
      throw new OtpError('OTP_EXPIRED',
        'OTP has expired or does not exist. Please request a new one.');
    }

    // 2. Check attempts
    const attempts = parseInt(await redis.get(attemptsKey) || 0);
    if (attempts >= OTP_MAX_ATTEMPTS) {
      await redis.del(otpKey); // Invalidate OTP after max attempts
      throw new OtpError('MAX_ATTEMPTS_EXCEEDED',
        'Too many incorrect attempts. Please request a new OTP.');
    }

    // 3. Compare OTP
    const isValid = await bcrypt.compare(otpInput.toString(), hashedOtp);

    if (!isValid) {
      // Increment attempts
      await redis.incr(attemptsKey);
      await redis.expire(attemptsKey, Math.floor(OTP_EXPIRES_MS / 1000));

      const remaining = OTP_MAX_ATTEMPTS - (attempts + 1);
      throw new OtpError('INVALID_OTP',
        `Incorrect OTP. ${remaining} attempt${remaining === 1 ? '' : 's'} remaining.`,
        { remainingAttempts: remaining });
    }

    // 4. OTP is valid — clean up Redis
    await redis.del(otpKey);
    await redis.del(attemptsKey);

    // 5. Mark as used in MongoDB
    await OtpRecord.findOneAndUpdate(
      {
        email: normalizedEmail,
        type,
        isUsed: false,
        expiresAt: { $gt: new Date() },
      },
      {
        isUsed: true,
        usedAt: new Date(),
      },
      { sort: { createdAt: -1 } }
    );

    logger.info(`OTP verified for ${normalizedEmail} [${type}]`);
    return true;
  }

  // ── Get OTP status (for resend timer) ─────────────────
  async getOtpStatus(email, type) {
    const redis = getRedis();
    const normalizedEmail = email.toLowerCase().trim();

    const cooldownKey = `${REDIS_KEYS.OTP_COOLDOWN}${normalizedEmail}:${type}`;
    const otpKey = `${REDIS_KEYS.OTP}${normalizedEmail}:${type}`;
    const attemptsKey = `${REDIS_KEYS.OTP_ATTEMPTS}${normalizedEmail}:${type}`;

    const [cooldownTtl, otpTtl, attempts] = await Promise.all([
      redis.ttl(cooldownKey),
      redis.ttl(otpKey),
      redis.get(attemptsKey),
    ]);

    return {
      canResend: cooldownTtl <= 0,
      resendAfterSeconds: Math.max(0, cooldownTtl),
      otpExpiresInSeconds: Math.max(0, otpTtl),
      attemptsUsed: parseInt(attempts || 0),
      attemptsRemaining: Math.max(0, OTP_MAX_ATTEMPTS - parseInt(attempts || 0)),
    };
  }

  // ── Invalidate all OTPs for email ─────────────────────
  async invalidateAllOtps(email) {
    const redis = getRedis();
    const normalizedEmail = email.toLowerCase().trim();

    const types = Object.values(OTP_TYPES);
    const deletePromises = types.map(type => {
      return Promise.all([
        redis.del(`${REDIS_KEYS.OTP}${normalizedEmail}:${type}`),
        redis.del(`${REDIS_KEYS.OTP_ATTEMPTS}${normalizedEmail}:${type}`),
      ]);
    });

    await Promise.all(deletePromises);
    logger.info(`All OTPs invalidated for ${normalizedEmail}`);
  }
}

// Custom error class for OTP errors
class OtpError extends Error {
  constructor(code, message, data = {}) {
    super(message);
    this.name = 'OtpError';
    this.code = code;
    this.data = data;
  }
}

module.exports = { OtpService: new OtpService(), OtpError };
