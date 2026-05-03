// server/src/routes/reel.routes.js

const express = require('express');
const router = express.Router();

const {
    createReel,
    getReelsFeed,
    getExploreReels,
    getReel,
    getUserReels,
    recordPlay,
    likeReel,
    unlikeReel,
    getReelLikers,
    getReelComments,
    addReelComment,
    deleteReel,
} = require('../controllers/reel.controller');

const { protect, optionalAuth } = require('../middleware/auth.middleware');

// ─── Multer for reel video upload ─────────────────────
const multer = require('multer');

const storage = multer.memoryStorage();

const reelVideoFilter = (req, file, cb) => {
    const allowedTypes = [
        'video/mp4',
        'video/quicktime',
        'video/x-msvideo',
        'video/webm',
        'video/3gpp',
        'video/mpeg',
    ];

    if (allowedTypes.includes(file.mimetype)) {
        cb(null, true);
    } else {
        cb(
            new Error('Only video files are allowed for reels (MP4, MOV, WebM)'),
            false
        );
    }
};

const uploadReelVideo = multer({
    storage,
    limits: { fileSize: 100 * 1024 * 1024 }, // 100MB
    fileFilter: reelVideoFilter,
});

// ─── Multer error handler ─────────────────────────────
const handleMulterError = (err, req, res, next) => {
    if (err) {
        if (err.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({
                success: false,
                message: 'Video file too large. Maximum size is 100MB.',
                timestamp: new Date().toISOString(),
            });
        }
        return res.status(400).json({
            success: false,
            message: err.message || 'File upload error',
            timestamp: new Date().toISOString(),
        });
    }
    next();
};

// ─────────────────────────────────────────────────────
// ROUTES
// ─────────────────────────────────────────────────────

// ─── Specific routes first (before :reelId) ───────────
router.get('/feed', protect, getReelsFeed);
router.get('/explore', optionalAuth, getExploreReels);
router.get('/user/:username', optionalAuth, getUserReels);

// ─── Create reel (video upload) ───────────────────────
router.post(
    '/',
    protect,
    (req, res, next) => {
        uploadReelVideo.single('video')(req, res, (err) => {
            handleMulterError(err, req, res, next);
        });
    },
    createReel
);

// ─── Single reel ──────────────────────────────────────
router.get('/:reelId', optionalAuth, getReel);
router.delete('/:reelId', protect, deleteReel);

// ─── Engagement ───────────────────────────────────────
router.post('/:reelId/play', optionalAuth, recordPlay);
router.post('/:reelId/like', protect, likeReel);
router.delete('/:reelId/like', protect, unlikeReel);
router.get('/:reelId/likes', optionalAuth, getReelLikers);

// ─── Comments ─────────────────────────────────────────
router.get('/:reelId/comments', optionalAuth, getReelComments);
router.post('/:reelId/comments', protect, addReelComment);

module.exports = router;