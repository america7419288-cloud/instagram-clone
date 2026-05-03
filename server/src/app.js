const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const app = express();
app.use(helmet());

const normalizeOrigin = (origin) => origin?.trim().replace(/\/$/, '');
const reelRoutes = require('./routes/reel.routes');


const allowedOrigins = [
    process.env.CLIENT_URL,
    process.env.CORS_ORIGIN,
    process.env.CORS_ORIGINS
]
    .filter(Boolean)
    .flatMap((origin) => origin.split(','))
    .map(normalizeOrigin)
    .filter(Boolean);

const allowAllOrigins = allowedOrigins.includes('*');
const storyAdvancedRoutes = require('./routes/story_advanced.routes');
const highlightRoutes = require('./routes/highlight.routes');

const isProduction = process.env.NODE_ENV === 'production' || process.env.MODE_ENV === 'production';

app.use(cors({
    origin: (origin, callback) => {
        const requestOrigin = normalizeOrigin(origin);

        if (
            !requestOrigin ||
            !isProduction ||
            allowAllOrigins ||
            allowedOrigins.includes(requestOrigin)
        ) {
            return callback(null, true);
        }

        console.warn(`Blocked by CORS: ${requestOrigin}`);
        return callback(new Error('Not allowed by CORS'));
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

if (process.env.MODE_ENV === 'production') {
    app.use(morgan('dev'))
}
app.get('/', (req, res) => {
    res.json({
        success: true,
        message: '🚀 Instagram Clone API is running!',
        version: '1.0.0',
        environment: process.env.MODE_ENV
    });
});

app.get('/health', (req, res) => {
    res.json({
        success: true,
        message: 'Server is healthy✅',
        timestamp: new Date().toISOString()
    });
});

app.use('/api/v1/auth', require('./routes/auth.routes'));
app.use('/api/v1/users', require('./routes/user.routes'));
app.use('/api/v1/posts', require('./routes/post.routes'));
app.use('/api/v1/users', require('./routes/follow.routes'));
app.use('/api/v1/comments', require('./routes/comment.routes'));
app.use('/api/v1/stories', require('./routes/story.routes'));
app.use('/api/v1/notifications', require('./routes/notification.routes'));
app.use('/api/v1/conversations', require('./routes/conversation.routes'));
app.use('/api/v1/messages', require('./routes/message.routes'));
app.use('/api/v1/stories', storyAdvancedRoutes);
app.use('/api/v1/highlights', highlightRoutes);
app.use('/api/v1/reels', reelRoutes);


app.get('/api/v1/test', (req, res) => {
    res.json({
        success: true,
        message: 'Flutter and Backend are Connected🎊',
        timestamp: new Date().toISOString()
    });
});


app.use('/*splat', (req, res) => {
    res.status(404).json({
        success: false,
        message: `Route ${req.originalUrl} not fount`
    });
});


app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(err.status || 500).json({
        success: false,
        message: err.message || 'Internal server error',
        ...(process.env.MODE_ENV === 'development' && { stack: err.stack })
    });
});

module.exports = app;
