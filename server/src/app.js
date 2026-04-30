const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
app.use(helmet());

const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    message: { success: false, message: 'Too many request' }
});
app.use('/api/', limiter);

app.use(cors({
    origin: '*',

    method: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json({limit: '10mb'}));
app.use(express.urlencoded({extended: true, limit: '10mb'}));

if (process.env.MODE_ENV === 'development'){
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
        ...(process.env.MODE_ENV === 'development' && {stack: err.stack})
    });
});

module.exports = app;