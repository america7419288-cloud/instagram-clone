// server/src/controllers/algorithm.controller.js

const { successResponse, errorResponse, paginatedResponse } = require('../utils/response.utils');
const { recordInteraction, getUserTopInterests } = require('../services/algorithm/interestEngine');
const { getFeedPosts } = require('../services/algorithm/feedAlgorithm');

// ─── Format post helper matching mobile client schemas ──────
const _formatPost = (post, userId) => {
  const mediaFiles = (post.mediaFiles || [])
    .sort((a, b) => a.order - b.order)
    .map((m) => ({
      id: m.id,
      url: m.url,
      media_url: m.url,
      thumbnailUrl: m.thumbnailUrl,
      thumbnail_url: m.thumbnailUrl,
      small_url: m.thumbnailUrl,
      medium_url: m.url,
      mediaType: m.mediaType,
      media_type: m.mediaType,
      duration: m.duration,
      width: m.width,
      height: m.height,
      order: m.order,
      display_order: m.order,
    }));

  const hasVideo = mediaFiles.some(m => m.mediaType === 'video');
  const hasMultiple = mediaFiles.length > 1;

  return {
    id: post.id,
    caption: post.caption,
    location: post.location,
    userId: post.userId,
    username: post.user?.username,
    fullName: post.user?.fullName,
    userAvatar: post.user?.profile_pic_url,
    isVerified: post.user?.is_verified || false,
    likesCount: post.likesCount || 0,
    commentsCount: post.commentsCount || 0,
    isLiked: userId ? (post.likes?.length > 0) : false,
    isSaved: userId ? (post.saves?.length > 0) : false,
    hasVideo,
    hasMultiple,
    createdAt: post.createdAt,
    updatedAt: post.updatedAt,
    mediaFiles,
    mentions: post.mentions || [],
    isPinned: post.isPinned || false,
    isArchived: post.isArchived || false,
    hideLikesCount: post.hideLikesCount || false,
    commentsDisabled: post.commentsDisabled || false,
    audience: post.audience || 'everyone',
    is_pinned: post.isPinned || false,
    is_archived: post.isArchived || false,
    hide_likes_count: post.hideLikesCount || false,
    comments_disabled: post.commentsDisabled || false,

    music: post.musicId ? {
      id: post.musicId,
      title: post.musicTitle,
      artist: post.musicArtist,
      startTime: post.musicStartTime,
      duration: post.musicDuration,
    } : null,

    media: mediaFiles,
    thumbnail_url: mediaFiles.length > 0 ? (mediaFiles[0].thumbnailUrl || mediaFiles[0].url) : null,
    media_type: mediaFiles.length > 0 ? mediaFiles[0].mediaType : 'image',
    is_carousel: hasMultiple,
    user: post.user ? {
      id: post.user.id,
      username: post.user.username,
      full_name: post.user.fullName,
      profile_pic_url: post.user.profile_pic_url,
      is_verified: post.user.is_verified || false,
    } : null,
    like_count: post.likesCount || 0,
    comment_count: post.commentsCount || 0,
    is_liked: userId ? (post.likes?.length > 0) : false,
    is_saved: userId ? (post.saves?.length > 0) : false,
  };
};

/**
 * Log interaction event from client
 * POST /api/v1/algorithms/interact
 */
const logInteraction = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      contentId,
      contentType,
      authorId,
      action,
      dwellTime = 0,
      source = 'feed',
      contentCategories = [],
      contentHashtags = [],
      sessionId,
    } = req.body;

    if (!contentId || !contentType || !action) {
      return errorResponse(res, 400, 'contentId, contentType and action are required parameters');
    }

    await recordInteraction({
      userId,
      contentId,
      contentType,
      authorId,
      action,
      dwellTime,
      source,
      contentCategories,
      contentHashtags,
      sessionId,
    });

    return successResponse(res, 'Interaction recorded successfully');

  } catch (error) {
    console.error('logInteraction error:', error.message);
    return errorResponse(res, 500, 'Failed to record interaction');
  }
};

/**
 * Serves ranked personalized Home Feed posts
 * GET /api/v1/algorithms/feed
 */
const getRankedFeed = async (req, res) => {
  try {
    const userId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 12;
    const { sessionId } = req.query;

    const result = await getFeedPosts({
      userId,
      page,
      limit,
      sessionId,
    });

    // Format all posts including any ad targeted cards
    const formatted = result.posts.map(p => {
      // If it is an ad card, return as plain object
      if (p.isAd) return p;
      return _formatPost(p, userId);
    });

    return paginatedResponse(res, 'Personalized feed loaded', formatted, {
      page,
      limit,
      hasNextPage: result.hasMore,
    });

  } catch (error) {
    console.error('getRankedFeed error:', error.message);
    return errorResponse(res, 500, 'Failed to load feed posts');
  }
};

/**
 * Fetch top user categories
 * GET /api/v1/algorithms/interests
 */
const getUserInterests = async (req, res) => {
  try {
    const userId = req.user.id;
    const limit = parseInt(req.query.limit) || 10;

    const interests = await getUserTopInterests(userId, limit);

    return successResponse(res, 'User interests loaded', interests);

  } catch (error) {
    console.error('getUserInterests error:', error.message);
    return errorResponse(res, 500, 'Failed to load user interests');
  }
};

module.exports = {
  logInteraction,
  getRankedFeed,
  getUserInterests,
};
