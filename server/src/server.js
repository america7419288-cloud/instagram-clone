const app = require('./app');
const { connectDB } = require('./config/database');
require('dotenv').config();

const PORT = process.env.PORT || 5000;

const startServer = async () => {
    try {
        await connectDB();

        const server = app.listen(PORT, () => {
            console.log('_____________________________________');
            console.log(`Environment: ${PORT}`);
            console.log(`🌍 Environment: ${process.env.NODE_ENV}`);
            console.log(`📡 URL: http://localhost:${PORT}`);
            console.log(`📱 Flutter can connect to this URL`);
            console.log('_____________________________________');
        });
        process.on('unhandeledRejection', (err) => {
            console.error('❌ UNHANDELED REJECTION:', err.message);
            server.close(() => process.exit(1));
        });
    } catch (error) {
        console.error('❌ failed to start server:', error);
        process.exit(1);
    }
};

startServer();