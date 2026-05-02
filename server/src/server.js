// server/src/server.js
// COMPLETE UPDATED FILE - Integrates Socket.io

const http = require('http');           // ⭐ NEW - Node's built-in http
const app = require('./app');
const { connectDB } = require('./config/database');
const { syncDatabase } = require('./models');
const { testCloudinary } = require('./config/cloudinary');
const { startCleanupJob } = require('./utils/cleanup.utils');
const { setupSocketServer } = require('./services/socket.service'); // ⭐ NEW

require('dotenv').config();

const PORT = process.env.PORT || 5000;

const startServer = async () => {
  try {
    // 1. Connect to database
    await connectDB();

    // 2. Sync models
    await syncDatabase();

    // 3. Test Cloudinary
    await testCloudinary();

    // 4. Start cleanup job
    startCleanupJob();

    // 5. Create HTTP server from Express app
    // ⭐ Socket.io needs the raw HTTP server (not just Express)
    const httpServer = http.createServer(app);

    // 6. Setup Socket.io on the HTTP server ⭐ NEW
    const io = setupSocketServer(httpServer);

    // 7. Make io accessible from controllers (optional)
    // This lets you emit events from REST API endpoints
    app.set('io', io);

    // 8. Start listening
    httpServer.listen(PORT, () => {
      console.log('─────────────────────────────────────────');
      console.log(`🚀 HTTP Server running on port ${PORT}`);
      console.log(`⚡ Socket.io running on port ${PORT}`);
      console.log(`🌍 Environment: ${process.env.NODE_ENV}`);
      console.log(`📡 API: http://localhost:${PORT}/api/v1`);
      console.log(`🔌 Socket: ws://localhost:${PORT}`);
      console.log('─────────────────────────────────────────');
      console.log('📌 Route groups active:');
      console.log('   /api/v1/auth');
      console.log('   /api/v1/users');
      console.log('   /api/v1/posts');
      console.log('   /api/v1/comments');
      console.log('   /api/v1/stories');
      console.log('   /api/v1/notifications');
      console.log('   /api/v1/conversations');
      console.log('   /api/v1/messages');
      console.log('─────────────────────────────────────────');
    });

    // Handle unexpected errors
    process.on('unhandledRejection', (err) => {
      console.error('❌ UNHANDLED REJECTION:', err.message);
      httpServer.close(() => process.exit(1));
    });

    process.on('uncaughtException', (err) => {
      console.error('❌ UNCAUGHT EXCEPTION:', err.message);
      process.exit(1);
    });

  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
};

startServer();