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
} = require('../models');
const {
  successResponse,
  errorResponse,
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
    const { caption, location } = req.body;
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
      });
    }

    // ─── Create post record ────────────────────────────
    const post = await Post.create({
      id: uuidv4(),
      userId,
      caption: caption?.trim() || null,
      location: location?.trim() || null,
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
        follower_id: userId,
        status: 'accepted',
      },
      attributes: ['following_id'],
    });

    const followingIds = following.map((f) => f.following_id);

    // ─── Include own posts in feed ────────────────────
    const feedUserIds = [userId, ...followingIds];

    if (feedUserIds.length === 1) {
      // Only self → return empty (no following yet)
      return successResponse(res, 200, 'Feed loaded', []);
    }

    // ─── Fetch posts ──────────────────────────────────
    const posts = await Post.findAll({
      where: {
        userId: { [Op.in]: feedUserIds },
      },
      include: _postIncludes(userId),
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

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
    const limit = parseInt(req.query.limit) || 30;
    const offset = (page - 1) * limit;

    // ─── Get who the user follows (exclude from explore) ─
    const following = await Follower.findAll({
      where: { follower_id: userId, status: 'accepted' },
      attributes: ['following_id'],
    });
    const followingIds = [
      userId,
      ...following.map((f) => f.following_id),
    ];

    // ─── Get posts NOT from followed users ────────────
    // Sort by engagement (likes + comments) + recency
    const posts = await Post.findAll({
      where: {
        userId: { [Op.notIn]: followingIds },
      },
      include: _postIncludes(userId),
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    const formatted = posts.map((p) => _formatPost(p, userId));

    return successResponse(res, 200, 'Explore posts loaded', formatted);
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

    const post = await _fetchPostById(postId, userId);

    if (!post) {
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

    const posts = await Post.findAll({
      where: { userId: user.id },
      include: _postIncludes(currentUserId),
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    const formatted = posts.map((p) => _formatPost(p, currentUserId));

    return successResponse(res, 200, 'User posts loaded', formatted);
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
    order: [['order', 'ASC']],
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
  console.log(`[DEBUG] Formatting post ${post.id}. Raw mediaFiles:`, JSON.stringify(post.mediaFiles));

  const mediaFiles = (post.mediaFiles || [])
    .sort((a, b) => a.order - b.order)
    .map((m) => ({
      id: m.id,
      media_url: m.url,
      thumbnail_url: m.thumbnailUrl,
      small_url: m.thumbnailUrl,
      medium_url: m.url,
      media_type: m.mediaType,
      duration: m.duration,
      width: m.width,
      height: m.height,
      display_order: m.order,
    }));

  return {
    id: post.id,
    caption: post.caption,
    location: post.location,
    media: mediaFiles,
    // ─── Profile grid fields ─────────────────────────
    thumbnail_url: mediaFiles.length > 0 ? (mediaFiles[0].small_url || mediaFiles[0].thumbnail_url || mediaFiles[0].media_url) : null,
    media_type: mediaFiles.length > 0 ? mediaFiles[0].media_type : 'image',
    is_carousel: mediaFiles.length > 1,
    // ─── User ────────────────────────────────────────
    user: post.user ? {
      id: post.user.id,
      username: post.user.username,
      full_name: post.user.fullName,
      profile_pic_url: post.user.profile_pic_url,
      is_verified: post.user.is_verified || false,
    } : null,
    // ─── Counts ──────────────────────────────────────
    like_count: post.likesCount || 0,
    comment_count: post.commentsCount || 0,
    save_count: 0,
    // ─── Current user state ───────────────────────────
    is_liked: userId ? (post.likes?.length > 0) : false,
    is_saved: userId ? (post.saves?.length > 0) : false,
    is_own_post: userId === post.userId,
    comments_disabled: false,
    // ─── Timestamps ──────────────────────────────────
    created_at: post.createdAt,
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
          type: 'mention',
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
