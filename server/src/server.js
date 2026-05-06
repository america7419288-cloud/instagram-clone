const http = require('http');
require('dotenv').config();

const app = require('./app');
const { testConnection } = require('./config/database');
const { syncDatabase } = require('./models');
const { testCloudinary } = require('./config/cloudinary');
const { startCleanupJob } = require('./utils/cleanup.utils');
const { setupSocketServer } = require('./services/socket.service');
const { initializeFirebase } = require('./config/firebase');

const PORT = process.env.PORT || 5000;
const HOST = process.env.HOST || '0.0.0.0';
const isProduction =
  process.env.NODE_ENV === 'production' ||
  process.env.MODE_ENV === 'production';

const apiBaseUrl =
  process.env.API_BASE_URL ||
  (isProduction ? `http://${HOST}:${PORT}` : `http://localhost:${PORT}`);
const socketBaseUrl =
  process.env.SOCKET_BASE_URL || apiBaseUrl.replace(/^http/, 'ws');
const shouldSyncDatabase =
  !isProduction || process.env.SYNC_DATABASE === 'true';

const startServer = async () => {
  let httpServer;

  try {
    await testConnection();

    if (shouldSyncDatabase) {
      await syncDatabase();
    } else {
      console.log(
        'Database sync skipped in production. Set SYNC_DATABASE=true to enable it.'
      );
    }

    await testCloudinary();
    startCleanupJob();
    initializeFirebase();

    app.set('trust proxy', isProduction ? 1 : false);

    httpServer = http.createServer(app);
    httpServer.keepAliveTimeout =
      Number(process.env.KEEP_ALIVE_TIMEOUT_MS) || 65000;
    httpServer.headersTimeout =
      Number(process.env.HEADERS_TIMEOUT_MS) || 66000;

    const io = setupSocketServer(httpServer);
    app.set('io', io);

    httpServer.listen(PORT, HOST, () => {
      console.log('-----------------------------------------');
      console.log(`HTTP server running on ${HOST}:${PORT}`);
      console.log(`Socket.io running on ${HOST}:${PORT}`);
      console.log(
        `Environment: ${process.env.NODE_ENV || process.env.MODE_ENV || 'development'}`
      );
      console.log(`API: ${apiBaseUrl}/api/v1`);
      console.log(`Socket: ${socketBaseUrl}`);
      console.log('-----------------------------------------');
      console.log('Route groups active:');
      console.log('   /api/v1/auth');
      console.log('   /api/v1/users');
      console.log('   /api/v1/posts');
      console.log('   /api/v1/comments');
      console.log('   /api/v1/stories');
      console.log('   /api/v1/notifications');
      console.log('   /api/v1/conversations');
      console.log('   /api/v1/messages');
      console.log('-----------------------------------------');
    });

    const shutdown = (signal) => {
      console.log(`${signal} received. Closing HTTP server...`);
      httpServer.close(() => {
        console.log('HTTP server closed.');
        process.exit(0);
      });
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));

    process.on('unhandledRejection', (err) => {
      console.error('UNHANDLED REJECTION:', err.message);
      if (httpServer) {
        httpServer.close(() => process.exit(1));
      } else {
        process.exit(1);
      }
    });

    process.on('uncaughtException', (err) => {
      console.error('UNCAUGHT EXCEPTION:', err.message);
      process.exit(1);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();
