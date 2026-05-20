// server/src/controllers/reel.controller.js

require('dotenv').config();

const { v4: uuidv4 } = require('uuid');
const { Op } = require('sequelize');
const {
    User,
    Reel, // test
    ReelLike,
    Comment,
    CommentLike,
    Follower,
    Notification,
    Block,
} = require('../models');
const { getBlockedUserIds } = require('../utils/block.utils');
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
                400,
                'Please select a video for your reel'
            );
        }

        // ─── Only videos allowed for reels ────────────────
        if (!file.mimetype.startsWith('video/')) {
            return errorResponse(
                res,
                400,
                'Reels must be video files (MP4, MOV, WebM)'
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
                400,
                `Reel is ${uploaded.duration}s. Maximum allowed is ${MAX_REEL_DURATION}s.`
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

        return successResponse(res, 201, 'Reel created successfully', fullReel);
    } catch (error) {
        console.error('❌ createReel error:', error);
        return errorResponse(
            res,
            500,
            error.message || 'Failed to create reel'
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

        const blockedUserIds = await getBlockedUserIds(userId);

        // ─── Strategy: Mix followed + trending ────────────
        // Fetch from followed users first
        const followedReels = await Reel.findAll({
            where: {
                userId: { 
                    [Op.in]: feedUserIds,
                    [Op.notIn]: blockedUserIds
                },
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
                    userId: { [Op.notIn]: [...feedUserIds, ...blockedUserIds] },
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

        return successResponse(res, 200, 'Reels feed loaded', formatted);
    } catch (error) {
        console.error('❌ getReelsFeed error:', error);
        return errorResponse(res, 500, 'Failed to load reels feed');
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

        const blockedUserIds = await getBlockedUserIds(userId);

        const reels = await Reel.findAll({
            where: { 
                isPublic: true,
                userId: { [Op.notIn]: blockedUserIds }
            },
            include: _reelIncludes(userId),
            order: [
                ['playsCount', 'DESC'],
                ['likesCount', 'DESC'],
                ['createdAt', 'DESC'],
            ],
            limit,
            offset,
        });

        const formatted = reels.map((r) => _formatReel(r, userId));
        return successResponse(res, 200, 'Explore reels loaded', formatted);
    } catch (error) {
        console.error('❌ getExploreReels error:', error);
        return errorResponse(res, 500, 'Failed to load explore reels');
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
            return errorResponse(res, 404, 'Reel not found');
        }

        return successResponse(res, 200, 'Reel loaded', reel);
    } catch (error) {
        console.error('❌ getReel error:', error);
        return errorResponse(res, 500, 'Failed to load reel');
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
            return errorResponse(res, 404, 'User not found');
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
        return successResponse(res, 200, 'User reels loaded', formatted);
    } catch (error) {
        console.error('❌ getUserReels error:', error);
        return errorResponse(res, 500, 'Failed to load user reels');
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
            return errorResponse(res, 404, 'Reel not found');
        }

        // Increment plays count
        await reel.increment('playsCount');

        return successResponse(res, 200, 'Play recorded');
    } catch (error) {
        console.error('❌ recordPlay error:', error);
        // Non-critical, don't return error to client
        return successResponse(res, 200, 'Play recorded');
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
            return errorResponse(res, 404, 'Reel not found');
        }

        // ─── Check already liked ──────────────────────────
        const existing = await ReelLike.findOne({
            where: { userId, reelId },
        });

        if (existing) {
            return errorResponse(res, 400, 'Reel already liked');
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

        return successResponse(res, 200, 'Reel liked');
    } catch (error) {
        console.error('❌ likeReel error:', error);
        return errorResponse(res, 500, 'Failed to like reel');
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
            return errorResponse(res, 400, 'Reel not liked');
        }

        await like.destroy();

        const reel = await Reel.findByPk(reelId, {
            attributes: ['id', 'likesCount'],
        });

        if (reel && reel.likesCount > 0) {
            await reel.decrement('likesCount');
        }

        return successResponse(res, 200, 'Reel unliked');
    } catch (error) {
        console.error('❌ unlikeReel error:', error);
        return errorResponse(res, 500, 'Failed to unlike reel');
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

        const blockedUserIds = await getBlockedUserIds(req.user.id);

        const likes = await ReelLike.findAll({
            where: {
                reelId,
                userId: { [Op.notIn]: blockedUserIds },
            },
            include: [
                {
                    model: User,
                    as: 'user',
                    attributes: [
                        'id',
                        'username',
                        'fullName',
                        'profile_pic_url',
                        'is_verified',
                    ],
                },
            ],
            order: [['createdAt', 'DESC']],
            limit,
            offset,
        });

        const users = likes.map((l) => l.user);
        return successResponse(res, 200, 'Reel likers loaded', users);
    } catch (error) {
        console.error('❌ getReelLikers error:', error);
        return errorResponse(res, 500, 'Failed to get reel likers');
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

        const blockedUserIds = await getBlockedUserIds(userId);

        const comments = await Comment.findAll({
            where: {
                reelId,
                parentCommentId: null, // Top-level only
                userId: { [Op.notIn]: blockedUserIds },
            },
            include: [
                {
                    model: User,
                    as: 'user',
                    attributes: [
                        'id',
                        'username',
                        'profile_pic_url',
                        'is_verified',
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
                ['is_pinned', 'DESC'],
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
            userAvatar: c.user?.profile_pic_url,
            isVerified: c.user?.is_verified || false,
            content: c.content,
            likesCount: c.like_count || c.likesCount,
            repliesCount: c.replies_count || c.repliesCount,
            isPinned: c.is_pinned,
            isLiked: userId ? (c.likes?.length > 0) : false,
            createdAt: c.createdAt,
        }));

        return successResponse(res, 200, 'Reel comments loaded', formatted);
    } catch (error) {
        console.error('❌ getReelComments error:', error);
        return errorResponse(res, 500, 'Failed to load reel comments');
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
            return errorResponse(res, 400, 'Comment text is required');
        }

        const reel = await Reel.findByPk(reelId, {
            attributes: ['id', 'userId'],
        });

        if (!reel) {
            return errorResponse(res, 404, 'Reel not found');
        }

        // ─── Check if blocked ─────────────────────────────
        const blockedUserIds = await getBlockedUserIds(userId);
        if (blockedUserIds.includes(reel.userId)) {
            return errorResponse(res, 403, 'You cannot comment on this reel');
        }

        const blockExists = await Block.findOne({
            where: {
                blocker_id: reel.userId,
                blocked_id: userId,
            },
        });
        if (blockExists) {
            return errorResponse(res, 403, 'You cannot comment on this reel');
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
            attributes: ['id', 'username', 'profile_pic_url', 'is_verified'],
        });

        return successResponse(
            res,
            201,
            'Comment added',
            {
                id: comment.id,
                reelId: comment.reelId,
                userId: comment.userId,
                username: user?.username,
                userAvatar: user?.profile_pic_url,
                isVerified: user?.is_verified || false,
                content: comment.content,
                likesCount: 0,
                repliesCount: 0,
                isPinned: false,
                isLiked: false,
                createdAt: comment.createdAt,
            }
        );
    } catch (error) {
        console.error('❌ addReelComment error:', error);
        return errorResponse(res, 500, 'Failed to add comment');
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
                404,
                'Reel not found or not yours'
            );
        }

        // ─── Delete from Cloudinary ───────────────────────
        if (reel.publicId) {
            await deleteFromCloudinary(reel.publicId, 'video');
        }

        // ─── Delete reel (cascade: likes, comments) ───────
        await reel.destroy();

        console.log(`🗑️  Reel deleted: ${reelId}`);
        return successResponse(res, 200, 'Reel deleted successfully');
    } catch (error) {
        console.error('❌ deleteReel error:', error);
        return errorResponse(res, 500, 'Failed to delete reel');
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
            'profile_pic_url',
            'is_verified',
            'is_private',
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
        userAvatar: reel.user?.profile_pic_url,
        isVerified: reel.user?.is_verified || false,
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
