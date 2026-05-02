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
      return errorResponse(res, 'Please select at least one photo or video', 400);
    }

    if (files.length > 10) {
      return errorResponse(res, 'Maximum 10 files per post', 400);
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
            `Video duration ${uploadResult.duration}s exceeds the ${MAX_POST_VIDEO_DURATION}s limit`,
            400
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
      'Post created successfully',
      completePost,
      201
    );
  } catch (error) {
    console.error('❌ createPost error:', error);
    return errorResponse(res, error.message || 'Failed to create post', 500);
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
    const feedUserIds = [userId, ...followingIds];

    if (feedUserIds.length === 1) {
      // Only self → return empty (no following yet)
      return successResponse(res, 'Feed loaded', []);
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

    return successResponse(res, 'Feed loaded', formatted);
  } catch (error) {
    console.error('❌ getFeed error:', error);
    return errorResponse(res, 'Failed to load feed', 500);
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
      where: { followerId: userId, status: 'accepted' },
      attributes: ['followingId'],
    });
    const followingIds = [
      userId,
      ...following.map((f) => f.followingId),
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

    return successResponse(res, 'Explore posts loaded', formatted);
  } catch (error) {
    console.error('❌ getExplorePosts error:', error);
    return errorResponse(res, 'Failed to load explore posts', 500);
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
      return errorResponse(res, 'Post not found', 404);
    }

    return successResponse(res, 'Post loaded', post);
  } catch (error) {
    console.error('❌ getPost error:', error);
    return errorResponse(res, 'Failed to load post', 500);
  }
};

// ─────────────────────────────────────────────────────
// GET USER POSTS
// GET /api/posts/user/:username
// ─────────────────────────────────────────────────────
const getUserPosts = async (req, res) => {
  try {
    const { username } = req.params;
    const currentUserId = req.user?.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    // ─── Find user ────────────────────────────────────
    const user = await User.findOne({
      where: { username },
      attributes: ['id'],
    });

    if (!user) {
      return errorResponse(res, 'User not found', 404);
    }

    const posts = await Post.findAll({
      where: { userId: user.id },
      include: _postIncludes(currentUserId),
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    const formatted = posts.map((p) => _formatPost(p, currentUserId));

    return successResponse(res, 'User posts loaded', formatted);
  } catch (error) {
    console.error('❌ getUserPosts error:', error);
    return errorResponse(res, 'Failed to load user posts', 500);
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
      return errorResponse(res, 'Post not found or not yours', 404);
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
    return successResponse(res, 'Post updated', updated);
  } catch (error) {
    console.error('❌ updatePost error:', error);
    return errorResponse(res, 'Failed to update post', 500);
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
      return errorResponse(res, 'Post not found or not yours', 404);
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

    return successResponse(res, 'Post deleted successfully');
  } catch (error) {
    console.error('❌ deletePost error:', error);
    return errorResponse(res, 'Failed to delete post', 500);
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
      return errorResponse(res, 'Post not found', 404);
    }

    // ─── Check already liked ──────────────────────────
    const existing = await Like.findOne({
      where: { userId, postId },
    });

    if (existing) {
      return errorResponse(res, 'Post already liked', 400);
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

    return successResponse(res, 'Post liked');
  } catch (error) {
    console.error('❌ likePost error:', error);
    return errorResponse(res, 'Failed to like post', 500);
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
      return errorResponse(res, 'Post not liked', 400);
    }

    await like.destroy();

    const post = await Post.findByPk(postId, { attributes: ['id', 'likesCount'] });
    if (post && post.likesCount > 0) {
      await post.decrement('likesCount');
    }

    return successResponse(res, 'Post unliked');
  } catch (error) {
    console.error('❌ unlikePost error:', error);
    return errorResponse(res, 'Failed to unlike post', 500);
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
          attributes: ['id', 'username', 'fullName', 'profilePicture', 'isVerified'],
        },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    const users = likes.map((l) => l.user);
    return successResponse(res, 'Post likers loaded', users);
  } catch (error) {
    console.error('❌ getPostLikers error:', error);
    return errorResponse(res, 'Failed to get post likers', 500);
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
    if (!post) return errorResponse(res, 'Post not found', 404);

    const existing = await SavedPost.findOne({ where: { userId, postId } });
    if (existing) return errorResponse(res, 'Post already saved', 400);

    await SavedPost.create({ id: uuidv4(), userId, postId });
    return successResponse(res, 'Post saved');
  } catch (error) {
    console.error('❌ savePost error:', error);
    return errorResponse(res, 'Failed to save post', 500);
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
    if (!saved) return errorResponse(res, 'Post not saved', 400);

    await saved.destroy();
    return successResponse(res, 'Post unsaved');
  } catch (error) {
    console.error('❌ unsavePost error:', error);
    return errorResponse(res, 'Failed to unsave post', 500);
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

    return successResponse(res, 'Saved posts loaded', formatted);
  } catch (error) {
    console.error('❌ getSavedPosts error:', error);
    return errorResponse(res, 'Failed to get saved posts', 500);
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
      return successResponse(res, 'Hashtag posts loaded', []);
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
    return successResponse(res, 'Hashtag posts loaded', formatted);
  } catch (error) {
    console.error('❌ getPostsByHashtag error:', error);
    return errorResponse(res, 'Failed to load hashtag posts', 500);
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
      'profilePicture',
      'isVerified',
      'isPrivate',
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
  const mediaFiles = (post.mediaFiles || [])
    .sort((a, b) => a.order - b.order)
    .map((m) => ({
      id: m.id,
      url: m.url,
      thumbnailUrl: m.thumbnailUrl,
      mediaType: m.mediaType,  // 'image' | 'video'
      duration: m.duration,
      width: m.width,
      height: m.height,
      order: m.order,
    }));

  return {
    id: post.id,
    userId: post.userId,
    username: post.user?.username,
    fullName: post.user?.fullName,
    userAvatar: post.user?.profilePicture,
    isVerified: post.user?.isVerified || false,
    caption: post.caption,
    location: post.location,
    mediaFiles,
    // ─── Counts ──────────────────────────────────────
    likesCount: post.likesCount || 0,
    commentsCount: post.commentsCount || 0,
    // ─── Current user state ───────────────────────────
    isLiked: userId ? (post.likes?.length > 0) : false,
    isSaved: userId ? (post.saves?.length > 0) : false,
    // ─── Timestamps ──────────────────────────────────
    createdAt: post.createdAt,
    updatedAt: post.updatedAt,
    // ─── Flags ────────────────────────────────────────
    hasVideo: mediaFiles.some((m) => m.mediaType === 'video'),
    hasMultiple: mediaFiles.length > 1,
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
