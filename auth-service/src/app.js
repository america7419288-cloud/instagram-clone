// src/app.js

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const logger = require('./utils/logger');

const authRoutes = require('./routes/auth.routes');
const healthRoutes = require('./routes/health.routes');
const { globalRateLimiter } = require('./middleware/rate-limit.middleware');
const { errorHandler } = require('./middleware/error.middleware');

const app = express();

// ── Security middleware ──────────────────────────────────
app.use(helmet());
app.use(cors({
  origin: [
    process.env.FRONTEND_URL || 'http://localhost:8080',
    process.env.MAIN_BACKEND_URL || 'http://localhost:3000',
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
}));

// ── Request parsing ──────────────────────────────────────
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true }));

// ── Logging ──────────────────────────────────────────────
app.use(morgan('combined', {
  stream: { write: (msg) => logger.info(msg.trim()) },
}));

// ── Global rate limiter ──────────────────────────────────
app.use(globalRateLimiter);

// ── Routes ───────────────────────────────────────────────
app.use('/health', healthRoutes);
app.use('/auth', authRoutes);

// ── 404 handler ──────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({
    success: false,
    code: 'ROUTE_NOT_FOUND',
    message: `Cannot ${req.method} ${req.path}`,
  });
});

// ── Global error handler ─────────────────────────────────
app.use(errorHandler);

module.exports = app;
