// src/routes/health.routes.js

const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { getRedis } = require('../config/redis');

router.get('/', async (req, res) => {
  let dbStatus = 'DISCONNECTED';
  let redisStatus = 'DISCONNECTED';

  if (mongoose.connection.readyState === 1) {
    dbStatus = 'CONNECTED';
  }

  try {
    const redis = getRedis();
    const ping = await redis.ping();
    if (ping === 'PONG') {
      redisStatus = 'CONNECTED';
    }
  } catch (_) {}

  const health = {
    uptime: process.uptime(),
    status: dbStatus === 'CONNECTED' && redisStatus === 'CONNECTED' ? 'OK' : 'DEGRADED',
    timestamp: Date.now(),
    services: {
      mongodb: dbStatus,
      redis: redisStatus,
    },
  };

  res.status(health.status === 'OK' ? 200 : 503).json(health);
});

module.exports = router;
