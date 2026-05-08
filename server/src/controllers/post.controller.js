// server/src/controllers/post.controller.js

const { v4: uuidv4 } = require('uuid');
const { Op } = require('sequelize');
const {
  User,
  Post,
  PostMedia,
  Like,
  SavedPost,
  Comment,
  Hashtag,
  PostHashtag,
  Follower,
  Reel,
  Block,
} = require('../models');
const { getBlockedUserIds } = require('../utils/block.utils');
const {
  successResponse,
  errorResponse,
  paginatedResponse,
} = require('../utils/response.utils');
const {
  uploadImageToCloudinary,
  uploadVideoToCloudinary,
  deleteFromCloudinary,
  getMediaType,
  MAX_POST_VIDEO_DURATION,
} = require('../services/upload.service');
const { extractHashtags } = require('../utils/hashtag.utils');
const { createNotification } = require('../services/notification.service');
const { emitToUser } = require('../services/socket.service');

// ─────────────────────────────────────────────────────
// CREATE POST (supports images + videos)
// POST /api/posts
// ─────────────────────────────────────────────────────
const createPost = async (req, res) => {
  try {
    const userId = req.user.id;
    const { 
      caption, 
      location,
      music_id,
      music_title,
      music_artist,
      music_start_time,
      music_duration
    } = req.body;
    const filters = req.body.filters || [];
    const files = req.files;

    // ─── Validate files ────────────────────────────────
    if (!files || files.length === 0) {
      return errorResponse(res, 400, 'Please select at least one photo or video');
    }

    if (files.length > 10) {
      return errorResponse(res, 400, 'Maximum 10 files per post');
    }

    // ─── Upload all media to Cloudinary ────────────────
    console.log(`📤 Uploading ${files.length} file(s) for post...`);

    const uploadedMedia = [];

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const mediaType = getMediaType(file.mimetype);

      let uploadResult;

      if (mediaType === 'video') {
        // ─── Upload video ────────────────────────────────
        uploadResult = await uploadVideoToCloudinary(
          file.buffer,
          file.mimetype
        );

        // ─── Validate video duration ─────────────────────
        if (
          uploadResult.duration &&
          uploadResult.duration > MAX_POST_VIDEO_DURATION
        ) {
          // Delete the too-long video from Cloudinary
          await deleteFromCloudinary(uploadResult.publicId, 'video');
          return errorResponse(
            res,
            400,
            `Video duration ${uploadResult.duration}s exceeds the ${MAX_POST_VIDEO_DURATION}s limit`
          );
        }
      } else {
        // ─── Upload image ────────────────────────────────
        uploadResult = await uploadImageToCloudinary(
          file.buffer,
          file.mimetype
        );
      }

      uploadedMedia.push({
        ...uploadResult,
        order: i,
        filterMatrix: Array.isArray(filters) ? filters[i] : filters[`${i}`],
      });
    }

    // ─── Create post record ────────────────────────────
    const post = await Post.create({
      id: uuidv4(),
      userId,
      caption: caption?.trim() || null,
      location: location?.trim() || null,
      musicId: music_id || null,
      musicTitle: music_title || null,
      musicArtist: music_artist || null,
      musicStartTime: music_start_time ? parseInt(music_start_time) : null,
      musicDuration: music_duration ? parseInt(music_duration) : null,
    });

    // ─── Create PostMedia records ──────────────────────
    const mediaRecords = await Promise.all(
      uploadedMedia.map((media) =>
        PostMedia.create({
          id: uuidv4(),
          postId: post.id,
          url: media.url,
          thumbnailUrl: media.thumbnailUrl,
          mediaType: media.mediaType,
          publicId: media.publicId,
          duration: media.duration,
          width: media.width,
          height: media.height,
          order: media.order,
          filterMatrix: media.filterMatrix,
        })
      )
    );

    // ─── Handle hashtags ───────────────────────────────
    if (caption) {
      await _processHashtags(post.id, caption);
    }

    // ─── Handle mentions ───────────────────────────────
    if (caption) {
      await _processMentions(caption, post.id, userId, req.user.username);
    }

    // ─── Fetch complete post to return ─────────────────
    const completePost = await _fetchPostById(post.id, userId);

    console.log(`✅ Post created: ${post.id} with ${mediaRecords.length} media files`);

    return successResponse(
      res,
      201,
      'Post created successfully',
      completePost
    );
  } catch (error) {
    console.error('❌ createPost error:', error);
    return errorResponse(res, 500, error.message || 'Failed to create post');
  }
};

// ─────────────────────────────────────────────────────
// GET FEED
// GET /api/posts/feed?page=1&limit=20
// ─────────────────────────────────────────────────────
const getFeed = async (req, res) => {
  try {
    const userId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    // ─── Get users that current user follows ──────────
    const following = await Follower.findAll({
      where: {
        followerId: userId,
        status: 'accepted',
      },
      attributes: ['followingId'],
    });

    const followingIds = following.map((f) => f.followingId);

    // ─── Include own posts in feed ────────────────────
    let feedUserIds = [userId, ...followingIds];
    const blockedUserIds = await getBlockedUserIds(userId);

    let posts;
    if (feedUserIds.length === 1) {
      // ─── FALLBACK: Discover Mode ────────────────────
      // If user follows no one, show recent global posts
      posts = await Post.findAll({
        where: {
          userId: { 
            [Op.ne]: userId, // Don't show only self
            [Op.notIn]: blockedUserIds
          },
          isArchived: { [Op.or]: [false, null] },
        },
        include: _postIncludes(userId),
        order: [['createdAt', 'DESC']],
        limit,
        offset,
      });
    } else {
      // ─── STANDARD: Following Feed ───────────────────
      posts = await Post.findAll({
        where: {
          userId: { 
            [Op.in]: feedUserIds,
            [Op.notIn]: blockedUserIds
          },
          isArchived: { [Op.or]: [false, null] },
        },
        include: _postIncludes(userId),
        order: [['createdAt', 'DESC']],
        limit,
        offset,
      });
    }

    const formatted = posts.map((p) => _formatPost(p, userId));

    return successResponse(res, 200, 'Feed loaded', formatted);
  } catch (error) {
    console.error('❌ getFeed error:', error);
    return errorResponse(res, 500, 'Failed to load feed');
  }
};

// ─────────────────────────────────────────────────────
// GET EXPLORE POSTS
// GET /api/posts/explore?page=1&limit=30
// ─────────────────────────────────────────────────────
const getExplorePosts = async (req, res) => {
  try {
    const userId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 24;
    const offset = (page - 1) * limit;

    // ─── Get who the user follows ──────────────────────
    const following = await Follower.findAll({
      where: { followerId: userId, status: 'accepted' },
      attributes: ['followingId'],
    });
    const followingIds = [userId, ...following.map((f) => f.followingId)];

    const blockedUserIds = await getBlockedUserIds(userId);

    // ─── 1. Fetch Posts (75% of limit) ────────────────
    const postLimit = Math.ceil(limit * 0.75);
    const posts = await Post.findAll({
      where: {
        userId: { 
          [Op.notIn]: [...followingIds, ...blockedUserIds] 
        },
        isArchived: { [Op.or]: [false, null] },
      },
      include: _postIncludes(userId),
      order: [['createdAt', 'DESC']],
      limit: postLimit,
      offset: (page - 1) * postLimit,
    });

    // ─── 2. Fetch Reels (25% of limit) ────────────────
    const reelLimit = limit - posts.length;
    let reels = [];
    if (reelLimit > 0) {
      reels = await Reel.findAll({
        where: {
          userId: { [Op.notIn]: [...followingIds, ...blockedUserIds] },
          isPublic: true,
        },
        include: [
          {
            model: User,
            as: 'user',
            attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified'],
          },
        ],
        order: [['createdAt', 'DESC']],
        limit: reelLimit,
        offset: (page - 1) * reelLimit,
      });
    }

    // ─── 3. Format and Combine ────────────────────────
    const formattedPosts = posts.map((p) => _formatPost(p, userId));
    const formattedReels = reels.map((r) => ({
      id: r.id,
      userId: r.userId,
      username: r.user?.username,
      thumbnail_url: r.thumbnailUrl,
      video_url: r.videoUrl, // Add this
      media_type: 'video', // Mark as video for the grid icon
      isReel: true,
      caption: r.caption,
      createdAt: r.createdAt,
    }));

    // Interleave: Post, Post, Reel, Post, Post, Reel...
    const combined = [];
    let pIdx = 0;
    let rIdx = 0;
    
    while (pIdx < formattedPosts.length || rIdx < formattedReels.length) {
      // Add up to 3 posts
      for (let i = 0; i < 3 && pIdx < formattedPosts.length; i++) {
        combined.push(formattedPosts[pIdx++]);
      }
      // Add 1 reel
      if (rIdx < formattedReels.length) {
        combined.push(formattedReels[rIdx++]);
      }
    }

    return successResponse(res, 200, 'Explore feed loaded', {
      posts: combined,
      has_next: posts.length === postLimit || reels.length === reelLimit,
    });
  } catch (error) {
    console.error('❌ getExplorePosts error:', error);
    return errorResponse(res, 500, 'Failed to load explore posts');
  }
};

// ─────────────────────────────────────────────────────
// GET SINGLE POST
// GET /api/posts/:postId
// ─────────────────────────────────────────────────────
const getPost = async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user?.id;

    const blockedUserIds = await getBlockedUserIds(userId);
    const post = await _fetchPostById(postId, userId);

    if (!post || blockedUserIds.includes(post.userId)) {
      return errorResponse(res, 404, 'Post not found');
    }

    return successResponse(res, 200, 'Post loaded', post);
  } catch (error) {
    console.error('❌ getPost error:', error);
    return errorResponse(res, 500, 'Failed to load post');
  }
};

// ─────────────────────────────────────────────────────
// GET USER POSTS
// GET /api/posts/user/:username
// ─────────────────────────────────────────────────────
const getUserPosts = async (req, res) => {
  try {
    const identifier = req.params.username;
    const currentUserId = req.user?.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    // ─── Find user (by UUID or username) ──────────────
    const isUuid = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(identifier);
    const user = await User.findOne({
      where: isUuid ? { id: identifier } : { username: identifier },
      attributes: ['id'],
    });

    if (!user) {
      return errorResponse(res, 404, 'User not found');
    }

    const blockedUserIds = await getBlockedUserIds(currentUserId);
    if (blockedUserIds.includes(user.id)) {
      return errorResponse(res, 404, 'User not found');
    }

    const { count, rows: posts } = await Post.findAndCountAll({
      where: {
        userId: user.id,
        isArchived: { [Op.or]: [false, null] },
      },
      include: _postIncludes(currentUserId),
      order: [['createdAt', 'DESC']],
      limit,
      offset,
      distinct: true,
    });

    const formatted = posts.map((p) => _formatPost(p, currentUserId));

    return paginatedResponse(res, 'User posts loaded', formatted, {
      page,
      totalPages: Math.ceil(count / limit),
      totalItems: count,
      limit,
    });
  } catch (error) {
    console.error('❌ getUserPosts error:', error);
    return errorResponse(res, 500, 'Failed to load user posts');
  }
};

// ─────────────────────────────────────────────────────
// UPDATE POST
// PUT /api/posts/:postId
// ─────────────────────────────────────────────────────
const updatePost = async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user.id;
    const { caption, location } = req.body;

    const post = await Post.findOne({
      where: { id: postId, userId },
    });

    if (!post) {
      return errorResponse(res, 404, 'Post not found or not yours');
    }

    await post.update({
      caption: caption?.trim() ?? post.caption,
      location: location?.trim() ?? post.location,
    });

    // ─── Re-process hashtags if caption changed ────────
    if (caption !== undefined) {
      // Remove old hashtag associations
      await PostHashtag.destroy({ where: { postId } });
      if (caption) {
        await _processHashtags(postId, caption);
      }
    }

    const updated = await _fetchPostById(postId, userId);
    return successResponse(res, 200, 'Post updated', updated);
  } catch (error) {
    console.error('❌ updatePost error:', error);
    return errorResponse(res, 500, 'Failed to update post');
  }
};

// ─────────────────────────────────────────────────────
// DELETE POST
// DELETE /api/posts/:postId
// ─────────────────────────────────────────────────────
const deletePost = async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user.id;

    const post = await Post.findOne({
      where: { id: postId, userId },
      include: [{ model: PostMedia, as: 'mediaFiles' }],
    });

    if (!post) {
      return errorResponse(res, 404, 'Post not found or not yours');
    }

    // ─── Delete media from Cloudinary ─────────────────
    for (const media of post.mediaFiles) {
      if (media.publicId) {
        const resourceType = media.mediaType === 'video' ? 'video' : 'image';
        await deleteFromCloudinary(media.publicId, resourceType);
      }
    }

    // ─── Delete post (cascade deletes media, likes, comments) ─
    await post.destroy();

    return successResponse(res, 200, 'Post deleted successfully');
  } catch (error) {
    console.error('❌ deletePost error:', error);
    return errorResponse(res, 500, 'Failed to delete post');
  }
};

// ─────────────────────────────────────────────────────
// LIKE POST
// POST /api/posts/:postId/like
// ─────────────────────────────────────────────────────
const likePost = async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user.id;

    const post = await Post.findByPk(postId, {
      attributes: ['id', 'userId'],
    });

    if (!post) {
      return errorResponse(res, 404, 'Post not found');
    }

    // ─── Check if blocked ─────────────────────────────
    const blockedUserIds = await getBlockedUserIds(userId);
    if (blockedUserIds.includes(post.userId)) {
      return errorResponse(res, 403, 'You cannot like this post');
    }

    const blockExists = await Block.findOne({
      where: {
        blocker_id: post.userId,
        blocked_id: userId,
      },
    });
    if (blockExists) {
      return errorResponse(res, 403, 'You cannot like this post');
    }

    // ─── Check already liked ──────────────────────────
    const existing = await Like.findOne({
      where: { userId, postId },
    });

    if (existing) {
      return errorResponse(res, 400, 'Post already liked');
    }

    await Like.create({
      id: uuidv4(),
      userId,
      postId,
    });

    // ─── Update like count on post ────────────────────
    await post.increment('likesCount');

    // ─── Create notification (not for own post) ───────
    if (post.userId !== userId) {
      const notification = await createNotification({
        recipientId: post.userId,
        senderId: userId,
        type: 'like',
        postId,
      });

      // ─── Emit via socket ──────────────────────────────
      if (notification) {
        emitToUser(post.userId, 'new-notification', notification);
      }
    }

    return successResponse(res, 200, 'Post liked');
  } catch (error) {
    console.error('❌ likePost error:', error);
    return errorResponse(res, 500, 'Failed to like post');
  }
};

// ─────────────────────────────────────────────────────
// UNLIKE POST
// DELETE /api/posts/:postId/like
// ─────────────────────────────────────────────────────
const unlikePost = async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user.id;

    const like = await Like.findOne({ where: { userId, postId } });

    if (!like) {
      return errorResponse(res, 400, 'Post not liked');
    }

    await like.destroy();

    const post = await Post.findByPk(postId, { attributes: ['id', 'likesCount'] });
    if (post && post.likesCount > 0) {
      await post.decrement('likesCount');
    }

    return successResponse(res, 200, 'Post unliked');
  } catch (error) {
    console.error('❌ unlikePost error:', error);
    return errorResponse(res, 500, 'Failed to unlike post');
  }
};

// ─────────────────────────────────────────────────────
// GET POST LIKERS
// GET /api/posts/:postId/likes
// ─────────────────────────────────────────────────────
const getPostLikers = async (req, res) => {
  try {
    const { postId } = req.params;
    const currentUserId = req.user?.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const likes = await Like.findAll({
      where: { postId },
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified'],
        },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    const users = likes.map((l) => l.user);
    return successResponse(res, 200, 'Post likers loaded', users);
  } catch (error) {
    console.error('❌ getPostLikers error:', error);
    return errorResponse(res, 500, 'Failed to get post likers');
  }
};

// ─────────────────────────────────────────────────────
// SAVE POST
// POST /api/posts/:postId/save
// ─────────────────────────────────────────────────────
const savePost = async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user.id;

    const post = await Post.findByPk(postId, { attributes: ['id'] });
    if (!post) return errorResponse(res, 404, 'Post not found');

    const existing = await SavedPost.findOne({ where: { userId, postId } });
    if (existing) return errorResponse(res, 400, 'Post already saved');

    await SavedPost.create({ id: uuidv4(), userId, postId });
    return successResponse(res, 200, 'Post saved');
  } catch (error) {
    console.error('❌ savePost error:', error);
    return errorResponse(res, 500, 'Failed to save post');
  }
};

// ─────────────────────────────────────────────────────
// UNSAVE POST
// DELETE /api/posts/:postId/save
// ─────────────────────────────────────────────────────
const unsavePost = async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user.id;

    const saved = await SavedPost.findOne({ where: { userId, postId } });
    if (!saved) return errorResponse(res, 400, 'Post not saved');

    await saved.destroy();
    return successResponse(res, 200, 'Post unsaved');
  } catch (error) {
    console.error('❌ unsavePost error:', error);
    return errorResponse(res, 500, 'Failed to unsave post');
  }
};

// ─────────────────────────────────────────────────────
// GET SAVED POSTS
// GET /api/posts/saved
// ─────────────────────────────────────────────────────
const getSavedPosts = async (req, res) => {
  try {
    const userId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const savedPosts = await SavedPost.findAll({
      where: { userId },
      include: [
        {
          model: Post,
          as: 'post',
          include: _postIncludes(userId),
        },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    const formatted = savedPosts
      .filter((s) => s.post)
      .map((s) => _formatPost(s.post, userId));

    return successResponse(res, 200, 'Saved posts loaded', formatted);
  } catch (error) {
    console.error('❌ getSavedPosts error:', error);
    return errorResponse(res, 500, 'Failed to get saved posts');
  }
};

// ─────────────────────────────────────────────────────
// GET POSTS BY HASHTAG
// GET /api/posts/hashtag/:tag
// ─────────────────────────────────────────────────────
const getPostsByHashtag = async (req, res) => {
  try {
    const { tag } = req.params;
    const userId = req.user?.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const offset = (page - 1) * limit;

    const hashtag = await Hashtag.findOne({
      where: { name: tag.toLowerCase() },
    });

    if (!hashtag) {
      return successResponse(res, 200, 'Hashtag posts loaded', []);
    }

    const posts = await Post.findAll({
      include: [
        ..._postIncludes(userId),
        {
          model: Hashtag,
          as: 'hashtags',
          where: { id: hashtag.id },
          through: { attributes: [] },
        },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    const formatted = posts.map((p) => _formatPost(p, userId));
    return successResponse(res, 200, 'Hashtag posts loaded', formatted);
  } catch (error) {
    console.error('❌ getPostsByHashtag error:', error);
    return errorResponse(res, 500, 'Failed to load hashtag posts');
  }
};

// ─────────────────────────────────────────────────────
// PRIVATE HELPERS
// ─────────────────────────────────────────────────────

// ─── Standard includes for post queries ───────────────
const _postIncludes = (userId) => [
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
    model: PostMedia,
    as: 'mediaFiles',
    attributes: [
      'id',
      'url',
      'thumbnailUrl',
      'mediaType',
      'publicId',
      'duration',
      'width',
      'height',
      'order',
    ],
  },
  {
    model: Like,
    as: 'likes',
    where: userId ? { userId } : undefined,
    required: false,
    attributes: ['userId'],
  },
  {
    model: SavedPost,
    as: 'saves',
    where: userId ? { userId } : undefined,
    required: false,
    attributes: ['userId'],
  },
];

// ─── Fetch single post by ID ──────────────────────────
const _fetchPostById = async (postId, userId) => {
  const post = await Post.findOne({
    where: { id: postId },
    include: _postIncludes(userId),
  });

  if (!post) return null;
  return _formatPost(post, userId);
};

// ─── Format post for response ─────────────────────────
const _formatPost = (post, userId) => {

  const mediaFiles = (post.mediaFiles || [])
    .sort((a, b) => a.order - b.order)
    .map((m) => ({
      id: m.id,
      url: m.url, // Standard URL
      media_url: m.url, // Legacy snake_case
      thumbnailUrl: m.thumbnailUrl, // New camelCase
      thumbnail_url: m.thumbnailUrl, // Legacy snake_case
      small_url: m.thumbnailUrl,
      medium_url: m.url,
      mediaType: m.mediaType, // New camelCase
      media_type: m.mediaType, // Legacy snake_case
      duration: m.duration,
      width: m.width,
      height: m.height,
      order: m.order,
      display_order: m.order, // Legacy snake_case
    }));

  const hasVideo = mediaFiles.some(m => m.mediaType === 'video');
  const hasMultiple = mediaFiles.length > 1;

  return {
    id: post.id,
    caption: post.caption,
    location: post.location,
    
    // ─── NEW: camelCase fields for Flutter ────────────
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

    // ─── Music Metadata ──────────────────────────────
    music: post.musicId ? {
      id: post.musicId,
      title: post.musicTitle,
      artist: post.musicArtist,
      startTime: post.musicStartTime,
      duration: post.musicDuration,
    } : null,

    // ─── Legacy snake_case fields ────────────────────
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
    is_own_post: userId === post.userId,
    created_at: post.createdAt,
    music_info: post.musicId ? {
      id: post.musicId,
      title: post.musicTitle,
      artist: post.musicArtist,
      start_time: post.musicStartTime,
      duration: post.musicDuration,
    } : null,
  };
};

// ─── Process hashtags from caption ────────────────────
const _processHashtags = async (postId, caption) => {
  try {
    const tags = extractHashtags(caption);
    if (!tags.length) return;

    for (const tag of tags) {
      const [hashtag] = await Hashtag.findOrCreate({
        where: { name: tag.toLowerCase() },
        defaults: {
          id: uuidv4(),
          name: tag.toLowerCase(),
          postsCount: 0,
        },
      });

      await PostHashtag.findOrCreate({
        where: { postId, hashtagId: hashtag.id },
        defaults: { id: uuidv4(), postId, hashtagId: hashtag.id },
      });

      await hashtag.increment('postsCount');
    }
  } catch (error) {
    console.error('❌ _processHashtags error:', error.message);
  }
};

// ─── Process @mentions from caption ───────────────────
const _processMentions = async (caption, postId, senderId, senderUsername) => {
  try {
    const mentionRegex = /@([a-zA-Z0-9_.]+)/g;
    const mentions = [...caption.matchAll(mentionRegex)].map((m) => m[1]);
    if (!mentions.length) return;

    for (const username of mentions) {
      const user = await User.findOne({
        where: { username },
        attributes: ['id'],
      });

      if (user && user.id !== senderId) {
        await createNotification({
          recipientId: user.id,
          senderId,
          type: 'mention_post',
          postId,
        });
      }
    }
  } catch (error) {
    console.error('❌ _processMentions error:', error.message);
  }
};

module.exports = {
  createPost,
  getFeed,
  getExplorePosts,
  getPost,
  getUserPosts,
  updatePost,
  deletePost,
  likePost,
  unlikePost,
  getPostLikers,
  savePost,
  unsavePost,
  getSavedPosts,
  getPostsByHashtag,
};
