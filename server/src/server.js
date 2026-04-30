const app = require('./app');
const { connectDB } = require('./config/database');
const { syncDatabase } = require('./models');
const { testCloudinary } = require('./config/cloudinary');
require('dotenv').config();

const PORT = process.env.PORT || 5000;

const startServer = async () => {
  try {
    await connectDB();

    await syncDatabase();

    await testCloudinary();

    const server = app.listen(PORT, () => {
      console.log('─────────────────────────────────────');
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`🌍 Environment: ${process.env.NODE_ENV}`);
      console.log(`📡 API: http://localhost:${PORT}/api/v1`);
      console.log('─────────────────────────────────────');
      console.log('📌 Auth endpoints ready');
      console.log('📌 User endpoints ready');
      console.log('─────────────────────────────────────');
    });

    process.on('unhandledRejection', (err) => {
      console.error('❌ UNHANDLED REJECTION:', err.message);
      server.close(() => process.exit(1));
    });

  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
};

startServer();