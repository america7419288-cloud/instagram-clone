// src/config/redis.js

const { createClient } = require('redis');
const logger = require('../utils/logger');

let redisClient = null;

async function connectRedis() {
  redisClient = createClient({
    url: process.env.REDIS_URL,
    password: process.env.REDIS_PASSWORD || undefined,
    socket: {
      reconnectStrategy: (retries) => Math.min(retries * 50, 2000),
    },
  });

  redisClient.on('error', (err) => {
    logger.error('Redis error:', err.message);
  });

  redisClient.on('connect', () => {
    logger.info('✅ Redis connected');
  });

  redisClient.on('reconnecting', () => {
    logger.warn('Redis reconnecting...');
  });

  await redisClient.connect();
  return redisClient;
}

function getRedis() {
  if (!redisClient) {
    throw new Error('Redis not initialized. Call connectRedis() first.');
  }
  return redisClient;
}

module.exports = { connectRedis, getRedis };
