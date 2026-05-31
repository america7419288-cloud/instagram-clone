// src/config/redis.js

const { createClient } = require('redis');
const logger = require('../utils/logger');

let redisClient = null;

async function connectRedis() {
  redisClient = createClient({
    url: process.env.REDIS_URL,
    password: process.env.REDIS_PASSWORD || undefined,
    socket: {
      reconnectStrategy: (retries) => {
        if (retries > 3) {
          logger.warn('Redis reconnection limit reached. Service will run with memory fallback.');
          return false; // Stop reconnecting
        }
        return Math.min(retries * 50, 2000);
      },
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

  try {
    await redisClient.connect();
  } catch (err) {
    logger.warn('Redis offline. Falling back to local memory store.');
  }
  return redisClient;
}

class MemoryRedisClient {
  constructor() {
    this.store = new Map();
    this.isOpen = true;
    this.isMemory = true;
  }

  async get(key) {
    const item = this.store.get(key);
    if (!item) return null;
    if (item.expiresAt && item.expiresAt < Date.now()) {
      this.store.delete(key);
      return null;
    }
    return item.value;
  }

  async set(key, value) {
    this.store.set(key, { value: String(value), expiresAt: null });
    return 'OK';
  }

  async setEx(key, seconds, value) {
    this.store.set(key, {
      value: String(value),
      expiresAt: Date.now() + seconds * 1000
    });
    return 'OK';
  }

  async del(key) {
    const existed = this.store.has(key);
    this.store.delete(key);
    return existed ? 1 : 0;
  }

  async ttl(key) {
    const item = this.store.get(key);
    if (!item) return -2;
    if (item.expiresAt) {
      const remaining = Math.ceil((item.expiresAt - Date.now()) / 1000);
      if (remaining <= 0) {
        this.store.delete(key);
        return -2;
      }
      return remaining;
    }
    return -1;
  }

  async incr(key) {
    const item = this.store.get(key);
    let val = 0;
    let expiresAt = null;
    if (item) {
      if (item.expiresAt && item.expiresAt < Date.now()) {
        this.store.delete(key);
      } else {
        val = parseInt(item.value, 10) || 0;
        expiresAt = item.expiresAt;
      }
    }
    val += 1;
    this.store.set(key, { value: String(val), expiresAt });
    return val;
  }

  async expire(key, seconds) {
    const item = this.store.get(key);
    if (!item) return 0;
    item.expiresAt = Date.now() + seconds * 1000;
    return 1;
  }

  multi() {
    const commands = [];
    const chain = {
      incr: (key) => {
        commands.push(() => this.incr(key));
        return chain;
      },
      expire: (key, seconds) => {
        commands.push(() => this.expire(key, seconds));
        return chain;
      },
      exec: async () => {
        const results = [];
        for (const cmd of commands) {
          results.push(await cmd());
        }
        return results;
      }
    };
    return chain;
  }

  async sendCommand() {
    return null;
  }
}

const memoryClientInstance = new MemoryRedisClient();

function getRedis() {
  if (!redisClient) {
    throw new Error('Redis not initialized. Call connectRedis() first.');
  }
  if (redisClient.isOpen) {
    return redisClient;
  }
  return memoryClientInstance;
}

module.exports = { connectRedis, getRedis };
