// src/models/OtpRecord.js

const mongoose = require('mongoose');

// MongoDB record for OTP history/audit
// Actual OTP values are in Redis (fast + auto-expire)
const otpRecordSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    lowercase: true,
    index: true,
  },
  type: {
    type: String,
    enum: ['email_verify', 'password_reset', 'login', 'phone_verify'],
    required: true,
  },
  // Hashed OTP (never store plain OTP in DB)
  hashedOtp: {
    type: String,
    required: true,
    select: false,
  },
  isUsed: {
    type: Boolean,
    default: false,
  },
  usedAt: Date,
  attempts: {
    type: Number,
    default: 0,
  },
  expiresAt: {
    type: Date,
    required: true,
    index: { expireAfterSeconds: 0 }, // TTL index
  },
  ipAddress: String,
  userAgent: String,
}, {
  timestamps: true,
});

otpRecordSchema.index({ email: 1, type: 1, createdAt: -1 });

module.exports = mongoose.model('OtpRecord', otpRecordSchema);
