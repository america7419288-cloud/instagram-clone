// server/src/controllers/reel.controller.js

require('dotenv').config();

const { v4: uuidv4 } = require('uuid');
const { Op } = require('sequelize');
const {
    User,
    Reel,
    ReelLike,
    Comment,
    CommentLike,
    Follower,
    Notification,
} = require('../models');
const {
    successResponse,
    errorResponse,
} = require('../utils/response.utils');
const {
    uploadReelToCloudinary,
    deleteFromCloudinary,
} = require('../services/upload.service');
const {
    createNotification,
} = require('../services/notification.service');
const { emitToUser } = require('../services/socket.service');

// ─── Max reel duration ────────────────────────────────
const MAX_REEL_DURATION = 60; // seconds

// ─────────────────────────────────────────────────────
// CREATE REEL
// POST /api/reels
// Body: multipart/form-data
//   - video: File (required)
//   - caption: string (optional)
//   - audioName: string (optional)
// ─────────────────────────────────────────────────────
const createReel = async (req, res) => {
    try {
        const userId = req.user.id;
        const { caption, audioName } = req.body;
        const file = req.file; // single file via multer

        // ─── Validate file ─────────────────────────────────
        if (!file) {
            return errorResponse(
                res,
                'Please select a video for your reel',
                400
            );
        }

        // ─── Only videos allowed for reels ────────────────
        if (!file.mimetype.startsWith('video/')) {
            return errorResponse(
                res,
                'Reels must be video files (MP4, MOV, WebM)',
                400
            );
        }

        // ─── Upload to Cloudinary ─────────────────────────
        console.log('📤 Uploading reel video...');
        const uploaded = await uploadReelToCloudinary(
            file.buffer,
            file.mimetype
        );

        // ─── Validate duration AFTER upload ───────────────
        if (uploaded.duration && uploaded.duration > MAX_REEL_DURATION) {
            // Delete the too-long reel from Cloudinary
            await deleteFromCloudinary(uploaded.publicId, 'video');

            return errorResponse(
                res,
                `Reel is ${uploaded.duration}s. Maximum allowed is ${MAX_REEL_DURATION}s.`,
                400
            );
        }

        // ─── Create reel record ───────────────────────────
        const reel = await Reel.create({
            id: uuidv4(),
            userId,
            videoUrl: uploaded.videoUrl,
            thumbnailUrl: uploaded.thumbnailUrl,
            publicId: uploaded.publicId,
            duration: uploaded.duration,
            width: uploaded.width,
            height: uploaded.height,
            caption: caption?.trim() || null,
            audioName: audioName?.trim() || null,
            audioType: audioName ? 'music' : 'original',
        });

        // ─── Fetch with user data ─────────────────────────
        const fullReel = await _fetchReelById(reel.id, userId);

        console.log(`✅ Reel created: ${reel.id}`);

        return successResponse(res, 'Reel created successfully', fullReel, 201);
    } catch (error) {
        console.error('❌ createReel error:', error);
        return errorResponse(
            res,
            error.message || 'Failed to create reel',
            500
        );
    }
};

// ─────────────────────────────────────────────────────
// GET REELS FEED
// GET /api/reels/feed?page=1&limit=10
// Returns reels from followed users + popular reels
// ─────────────────────────────────────────────────────
const getReelsFeed = async (req, res) => {
    try {
        const userId = req.user.id;
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const offset = (page - 1) * limit;

        // ─── Get followed user IDs ─────────────────────────
        const following = await Follower.findAll({
            where: {
                followerId: userId,
                status: 'accepted',
            },
            attributes: ['followingId'],
        });

        const followingIds = following.map((f) => f.followingId);
        const feedUserIds = [userId, ...followingIds];

        // ─── Strategy: Mix followed + trending ────────────
        // Fetch from followed users first
        const followedReels = await Reel.findAll({
            where: {
                userId: { [Op.in]: feedUserIds },
                isPublic: true,
            },
            include: _reelIncludes(userId),
            order: [['createdAt', 'DESC']],
            limit: Math.ceil(limit * 0.6), // 60% from following
            offset,
        });

        // ─── If not enough from following, add trending ───
        const remaining = limit - followedReels.length;
        let trendingReels = [];

        if (remaining > 0) {
            const followedReelIds = followedReels.map((r) => r.id);

            trendingReels = await Reel.findAll({
                where: {
                    userId: { [Op.notIn]: feedUserIds },
                    id: { [Op.notIn]: followedReelIds },
                    isPublic: true,
                },
                include: _reelIncludes(userId),
                // Sort by engagement for trending
                order: [
                    ['playsCount', 'DESC'],
                    ['likesCount', 'DESC'],
                    ['createdAt', 'DESC'],
                ],
                limit: remaining,
            });
        }

        // ─── Merge and shuffle slightly ───────────────────
        const allReels = [...followedReels, ...trendingReels];
        const formatted = allReels.map((r) => _formatReel(r, userId));

        return successResponse(res, 'Reels feed loaded', formatted);
    } catch (error) {
        console.error('❌ getReelsFeed error:', error);
        return errorResponse(res, 'Failed to load reels feed', 500);
    }
};

// ─────────────────────────────────────────────────────
// GET EXPLORE REELS (trending, not from following)
// GET /api/reels/explore?page=1&limit=20
// ─────────────────────────────────────────────────────
const getExploreReels = async (req, res) => {
    try {
        const userId = req.user?.id;
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const offset = (page - 1) * limit;

        const reels = await Reel.findAll({
            where: { isPublic: true },
            include: _reelIncludes(userId),
            order: [
                ['plays_count', 'DESC'],
                ['likes_count', 'DESC'],
                ['created_at', 'DESC'],
            ],
            limit,
            offset,
        });

        const formatted = reels.map((r) => _formatReel(r, userId));
        return successResponse(res, 'Explore reels loaded', formatted);
    } catch (error) {
        console.error('❌ getExploreReels error:', error);
        return errorResponse(res, 'Failed to load explore reels', 500);
    }
};

// ─────────────────────────────────────────────────────
// GET SINGLE REEL
// GET /api/reels/:reelId
// ─────────────────────────────────────────────────────
const getReel = async (req, res) => {
    try {
        const { reelId } = req.params;
        const userId = req.user?.id;

        const reel = await _fetchReelById(reelId, userId);

        if (!reel) {
            return errorResponse(res, 'Reel not found', 404);
        }

        return successResponse(res, 'Reel loaded', reel);
    } catch (error) {
        console.error('❌ getReel error:', error);
        return errorResponse(res, 'Failed to load reel', 500);
    }
};

// ─────────────────────────────────────────────────────
// GET USER REELS
// GET /api/reels/user/:username?page=1&limit=20
// ─────────────────────────────────────────────────────
const getUserReels = async (req, res) => {
    try {
        const { username } = req.params;
        const currentUserId = req.user?.id;
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const offset = (page - 1) * limit;

        // ─── Find the user ─────────────────────────────────
        const user = await User.findOne({
            where: { username },
            attributes: ['id'],
        });

        if (!user) {
            return errorResponse(res, 'User not found', 404);
        }

        const reels = await Reel.findAll({
            where: {
                userId: user.id,
                isPublic: true,
            },
            include: _reelIncludes(currentUserId),
            order: [['createdAt', 'DESC']],
            limit,
            offset,
        });

        const formatted = reels.map((r) => _formatReel(r, currentUserId));
        return successResponse(res, 'User reels loaded', formatted);
    } catch (error) {
        console.error('❌ getUserReels error:', error);
        return errorResponse(res, 'Failed to load user reels', 500);
    }
};

// ─────────────────────────────────────────────────────
// RECORD REEL PLAY
// POST /api/reels/:reelId/play
// Called when video starts playing (counts a view)
// ─────────────────────────────────────────────────────
const recordPlay = async (req, res) => {
    try {
        const { reelId } = req.params;

        const reel = await Reel.findByPk(reelId, {
            attributes: ['id'],
        });

        if (!reel) {
            return errorResponse(res, 'Reel not found', 404);
        }

        // Increment plays count
        await reel.increment('playsCount');

        return successResponse(res, 'Play recorded');
    } catch (error) {
        console.error('❌ recordPlay error:', error);
        // Non-critical, don't return error to client
        return successResponse(res, 'Play recorded');
    }
};

// ─────────────────────────────────────────────────────
// LIKE REEL
// POST /api/reels/:reelId/like
// ─────────────────────────────────────────────────────
const likeReel = async (req, res) => {
    try {
        const { reelId } = req.params;
        const userId = req.user.id;

        const reel = await Reel.findByPk(reelId, {
            attributes: ['id', 'userId'],
        });

        if (!reel) {
            return errorResponse(res, 'Reel not found', 404);
        }

        // ─── Check already liked ──────────────────────────
        const existing = await ReelLike.findOne({
            where: { userId, reelId },
        });

        if (existing) {
            return errorResponse(res, 'Reel already liked', 400);
        }

        // ─── Create like ──────────────────────────────────
        await ReelLike.create({
            id: uuidv4(),
            userId,
            reelId,
        });

        await reel.increment('likesCount');

        // ─── Notify reel owner ────────────────────────────
        if (reel.userId !== userId) {
            const notification = await createNotification({
                recipientId: reel.userId,
                senderId: userId,
                type: 'reel_like',
                reelId,
            });

            if (notification) {
                emitToUser(reel.userId, 'new-notification', notification);
            }
        }

        return successResponse(res, 'Reel liked');
    } catch (error) {
        console.error('❌ likeReel error:', error);
        return errorResponse(res, 'Failed to like reel', 500);
    }
};

// ─────────────────────────────────────────────────────
// UNLIKE REEL
// DELETE /api/reels/:reelId/like
// ─────────────────────────────────────────────────────
const unlikeReel = async (req, res) => {
    try {
        const { reelId } = req.params;
        const userId = req.user.id;

        const like = await ReelLike.findOne({
            where: { userId, reelId },
        });

        if (!like) {
            return errorResponse(res, 'Reel not liked', 400);
        }

        await like.destroy();

        const reel = await Reel.findByPk(reelId, {
            attributes: ['id', 'likesCount'],
        });

        if (reel && reel.likesCount > 0) {
            await reel.decrement('likesCount');
        }

        return successResponse(res, 'Reel unliked');
    } catch (error) {
        console.error('❌ unlikeReel error:', error);
        return errorResponse(res, 'Failed to unlike reel', 500);
    }
};

// ─────────────────────────────────────────────────────
// GET REEL LIKERS
// GET /api/reels/:reelId/likes?page=1&limit=20
// ─────────────────────────────────────────────────────
const getReelLikers = async (req, res) => {
    try {
        const { reelId } = req.params;
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const offset = (page - 1) * limit;

        const likes = await ReelLike.findAll({
            where: { reelId },
            include: [
                {
                    model: User,
                    as: 'user',
                    attributes: [
                        'id',
                        'username',
                        'fullName',
                        'profilePicture',
                        'isVerified',
                    ],
                },
            ],
            order: [['createdAt', 'DESC']],
            limit,
            offset,
        });

        const users = likes.map((l) => l.user);
        return successResponse(res, 'Reel likers loaded', users);
    } catch (error) {
        console.error('❌ getReelLikers error:', error);
        return errorResponse(res, 'Failed to get reel likers', 500);
    }
};

// ─────────────────────────────────────────────────────
// GET REEL COMMENTS
// GET /api/reels/:reelId/comments?page=1&limit=20
// ─────────────────────────────────────────────────────
const getReelComments = async (req, res) => {
    try {
        const { reelId } = req.params;
        const userId = req.user?.id;
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const offset = (page - 1) * limit;

        const comments = await Comment.findAll({
            where: {
                reelId,
                parentId: null, // Top-level only
            },
            include: [
                {
                    model: User,
                    as: 'user',
                    attributes: [
                        'id',
                        'username',
                        'profilePicture',
                        'isVerified',
                    ],
                },
                {
                    model: CommentLike,
                    as: 'likes',
                    where: userId ? { userId } : undefined,
                    required: false,
                    attributes: ['userId'],
                },
            ],
            order: [
                ['isPinned', 'DESC'],
                ['createdAt', 'DESC'],
            ],
            limit,
            offset,
        });

        const formatted = comments.map((c) => ({
            id: c.id,
            reelId: c.reelId,
            userId: c.userId,
            username: c.user?.username,
            userAvatar: c.user?.profilePicture,
            isVerified: c.user?.isVerified || false,
            content: c.content,
            likesCount: c.likesCount,
            repliesCount: c.repliesCount,
            isPinned: c.isPinned,
            isLiked: userId ? (c.likes?.length > 0) : false,
            createdAt: c.createdAt,
        }));

        return successResponse(res, 'Reel comments loaded', formatted);
    } catch (error) {
        console.error('❌ getReelComments error:', error);
        return errorResponse(res, 'Failed to load reel comments', 500);
    }
};

// ─────────────────────────────────────────────────────
// ADD REEL COMMENT
// POST /api/reels/:reelId/comments
// Body: { content: string }
// ─────────────────────────────────────────────────────
const addReelComment = async (req, res) => {
    try {
        const { reelId } = req.params;
        const userId = req.user.id;
        const { text } = req.body;

        if (!text || !text.trim()) {
            return errorResponse(res, 'Comment text is required', 400);
        }

        const reel = await Reel.findByPk(reelId, {
            attributes: ['id', 'userId'],
        });

        if (!reel) {
            return errorResponse(res, 'Reel not found', 404);
        }

        // ─── Create comment ───────────────────────────────
        const comment = await Comment.create({
            id: uuidv4(),
            reelId,     // ← reel comment
            postId: null,
            userId,
            content: text.trim(),
        });

        // ─── Increment reel comments count ────────────────
        await reel.increment('commentsCount');

        // ─── Notify reel owner ────────────────────────────
        if (reel.userId !== userId) {
            const notification = await createNotification({
                recipientId: reel.userId,
                senderId: userId,
                type: 'reel_comment',
                reelId,
            });

            if (notification) {
                emitToUser(reel.userId, 'new-notification', notification);
            }
        }

        // ─── Fetch with user data ─────────────────────────
        const user = await User.findByPk(userId, {
            attributes: ['id', 'username', 'profilePicture', 'isVerified'],
        });

        return successResponse(
            res,
            'Comment added',
            {
                id: comment.id,
                reelId: comment.reelId,
                userId: comment.userId,
                username: user?.username,
                userAvatar: user?.profilePicture,
                isVerified: user?.isVerified || false,
                content: comment.content,
                likesCount: 0,
                repliesCount: 0,
                isPinned: false,
                isLiked: false,
                createdAt: comment.createdAt,
            },
            201
        );
    } catch (error) {
        console.error('❌ addReelComment error:', error);
        return errorResponse(res, 'Failed to add comment', 500);
    }
};

// ─────────────────────────────────────────────────────
// DELETE REEL
// DELETE /api/reels/:reelId
// ─────────────────────────────────────────────────────
const deleteReel = async (req, res) => {
    try {
        const { reelId } = req.params;
        const userId = req.user.id;

        const reel = await Reel.findOne({
            where: { id: reelId, userId },
        });

        if (!reel) {
            return errorResponse(
                res,
                'Reel not found or not yours',
                404
            );
        }

        // ─── Delete from Cloudinary ───────────────────────
        if (reel.publicId) {
            await deleteFromCloudinary(reel.publicId, 'video');
        }

        // ─── Delete reel (cascade: likes, comments) ───────
        await reel.destroy();

        console.log(`🗑️  Reel deleted: ${reelId}`);
        return successResponse(res, 'Reel deleted successfully');
    } catch (error) {
        console.error('❌ deleteReel error:', error);
        return errorResponse(res, 'Failed to delete reel', 500);
    }
};

// ─────────────────────────────────────────────────────
// PRIVATE HELPERS
// ─────────────────────────────────────────────────────

// ─── Standard includes for reel queries ───────────────
const _reelIncludes = (userId) => [
    {
        model: User,
        as: 'user',
        attributes: [
            'id',
            'username',
            'fullName',
            'profilePicture',
            'isVerified',
            'isPrivate',
        ],
    },
    {
        model: ReelLike,
        as: 'likes',
        where: userId ? { userId } : undefined,
        required: false,
        attributes: ['userId'],
    },
];

// ─── Fetch single reel by ID ──────────────────────────
const _fetchReelById = async (reelId, userId) => {
    const reel = await Reel.findOne({
        where: { id: reelId },
        include: _reelIncludes(userId),
    });

    if (!reel) return null;
    return _formatReel(reel, userId);
};

// ─── Format reel for API response ─────────────────────
const _formatReel = (reel, userId) => {
    return {
        id: reel.id,
        userId: reel.userId,
        username: reel.user?.username,
        fullName: reel.user?.fullName,
        userAvatar: reel.user?.profilePicture,
        isVerified: reel.user?.isVerified || false,
        videoUrl: reel.videoUrl,
        thumbnailUrl: reel.thumbnailUrl,
        duration: reel.duration,
        width: reel.width,
        height: reel.height,
        caption: reel.caption,
        audioName: reel.audioName,
        audioType: reel.audioType,
        // ─── Counts ─────────────────────────────────────
        likesCount: reel.likesCount || 0,
        commentsCount: reel.commentsCount || 0,
        playsCount: reel.playsCount || 0,
        sharesCount: reel.sharesCount || 0,
        // ─── Current user state ──────────────────────────
        isLiked: userId ? (reel.likes?.length > 0) : false,
        isOwner: userId ? reel.userId === userId : false,
        // ─── Timestamps ──────────────────────────────────
        createdAt: reel.createdAt,
        updatedAt: reel.updatedAt,
    };
};

module.exports = {
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
};
