// src/models/User.js

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

const userSchema = new mongoose.Schema({
  // ── Identity ───────────────────────────────────────────
  uuid: {
    type: String,
    required: true,
    unique: true,
    index: true,
    default: () => crypto.randomUUID(),
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
    match: [/^\S+@\S+\.\S+$/, 'Invalid email format'],
    index: true,
  },
  username: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
    minlength: 3,
    maxlength: 30,
    match: [/^[a-z0-9._]+$/, 'Username can only contain letters, numbers, dots and underscores'],
    index: true,
  },
  fullName: {
    type: String,
    trim: true,
    maxlength: 60,
  },
  phone: {
    type: String,
    sparse: true,
    index: true,
  },

  // ── Password ───────────────────────────────────────────
  password: {
    type: String,
    minlength: 8,
    select: false, // Never returned by default
  },

  // ── Verification ───────────────────────────────────────
  isEmailVerified: {
    type: Boolean,
    default: false,
    index: true,
  },
  isPhoneVerified: {
    type: Boolean,
    default: false,
  },
  emailVerifiedAt: Date,

  // ── Account state ──────────────────────────────────────
  isActive: {
    type: Boolean,
    default: true,
  },
  isSuspended: {
    type: Boolean,
    default: false,
  },
  suspendedReason: String,
  suspendedAt: Date,
  deletedAt: Date, // soft delete

  // ── Auth providers ─────────────────────────────────────
  authProviders: [{
    provider: {
      type: String,
      enum: ['email', 'google', 'apple', 'facebook'],
    },
    providerId: String,
    connectedAt: { type: Date, default: Date.now },
  }],

  // ── Security ───────────────────────────────────────────
  loginAttempts: {
    type: Number,
    default: 0,
  },
  lockUntil: Date,
  lastLoginAt: Date,
  lastLoginIp: String,
  passwordChangedAt: Date,
  twoFactorEnabled: {
    type: Boolean,
    default: false,
  },
  twoFactorSecret: {
    type: String,
    select: false,
  },

  // ── Metadata ───────────────────────────────────────────
  registrationIp: String,
  deviceInfo: String,
}, {
  timestamps: true,
  toJSON: {
    transform(_, ret) {
      delete ret.password;
      delete ret.twoFactorSecret;
      delete ret.__v;
      return ret;
    },
  },
});

// ── Indexes ────────────────────────────────────────────
userSchema.index({ email: 1, isEmailVerified: 1 });
userSchema.index({ createdAt: -1 });

// ── Pre-save: hash password ────────────────────────────
userSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();
  if (!this.password) return next();

  // If already a bcrypt hash, skip hashing to prevent double-hashing on sync
  if (this.password.startsWith('$2a$') || this.password.startsWith('$2b$') || this.password.startsWith('$2y$')) {
    return next();
  }

  const salt = await bcrypt.genSalt(12);
  this.password = await bcrypt.hash(this.password, salt);
  this.passwordChangedAt = new Date();
  next();
});

// ── Methods ────────────────────────────────────────────
userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

userSchema.methods.isLocked = function () {
  return this.lockUntil && this.lockUntil > Date.now();
};

userSchema.methods.incrementLoginAttempts = async function () {
  const MAX_ATTEMPTS = 5;
  const LOCK_DURATION = 30 * 60 * 1000; // 30 minutes

  if (this.lockUntil && this.lockUntil < Date.now()) {
    // Reset after lock expired
    this.loginAttempts = 1;
    this.lockUntil = undefined;
  } else {
    this.loginAttempts += 1;
    if (this.loginAttempts >= MAX_ATTEMPTS) {
      this.lockUntil = Date.now() + LOCK_DURATION;
    }
  }
  return this.save();
};

userSchema.methods.resetLoginAttempts = async function () {
  this.loginAttempts = 0;
  this.lockUntil = undefined;
  this.lastLoginAt = new Date();
  return this.save();
};

module.exports = mongoose.model('AuthUser', userSchema);
