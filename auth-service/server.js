// server.js

require('dotenv').config();
const app = require('./src/app');
const { connectDatabase } = require('./src/config/database');
const { connectRedis } = require('./src/config/redis');
const logger = require('./src/utils/logger');

const PORT = process.env.PORT || 4000;

async function startServer() {
  try {
    // Connect databases
    await connectDatabase();
    await connectRedis();

    app.listen(PORT, () => {
      logger.info(`🔐 Auth Service running on port ${PORT}`);
      logger.info(`📧 Email verification: ENABLED`);
      logger.info(`🔑 OTP Service: ENABLED`);
    });
  } catch (error) {
    logger.error('Failed to start auth service:', error);
    process.exit(1);
  }
}

startServer();
