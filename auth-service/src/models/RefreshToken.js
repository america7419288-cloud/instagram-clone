// src/models/RefreshToken.js

const mongoose = require('mongoose');

const refreshTokenSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'AuthUser',
    required: true,
    index: true,
  },
  token: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  deviceId: String,
  deviceName: String,
  ipAddress: String,
  userAgent: String,
  isRevoked: {
    type: Boolean,
    default: false,
  },
  revokedAt: Date,
  revokedReason: String,
  expiresAt: {
    type: Date,
    required: true,
    index: { expireAfterSeconds: 0 }, // TTL
  },
  lastUsedAt: Date,
}, {
  timestamps: true,
});

refreshTokenSchema.index({ userId: 1, isRevoked: 1 });

module.exports = mongoose.model('RefreshToken', refreshTokenSchema);
