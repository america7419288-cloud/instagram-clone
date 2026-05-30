// src/utils/logger.js

const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    process.env.NODE_ENV === 'production'
      ? winston.format.json()
      : winston.format.combine(
          winston.format.colorize(),
          winston.format.printf(({ timestamp, level, message, stack }) => {
            return `[${timestamp}] ${level}: ${message}${stack ? `\n${stack}` : ''}`;
          })
        )
  ),
  defaultMeta: { service: process.env.SERVICE_NAME || 'auth-service' },
  transports: [
    new winston.transports.Console()
  ],
});

module.exports = logger;
