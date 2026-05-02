// server/src/controllers/post.controller.js

const {
  Post,
  PostMedia,
  User,
  Like,
  Hashtag,
  SavedPost,
  Comment,
  Follower,
  Block,
  sequelize,
} = require('../models');
const { successResponse, errorResponse, paginatedResponse } =
  require('../utils/response.utils');
const { uploadPostMedia, deleteFromCloudinary } =
  require('../services/upload.service');
const {
  saveHashtagsForPost,
  removeHashtagsForPost,
} = require('../utils/hashtag.utils');
const {
  notifyLike,
  processMentions,
} = require('../services/notification.service');
const { Op } = require('sequelize');

// ─── HELPER: Format post for response ──────────────────────
const formatPost = (post, currentUserId = null) => {
  const postData = post.toJSON ? post.toJSON() : post;

  return {
    id: postData.id,
    caption: postData.caption,
    location: postData.location,
    alt_text: postData.alt_text,
    comments_disabled: postData.comments_disabled,
    created_at: postData.created_at || postData.createdAt,
    updated_at: postData.updated_at || postData.updatedAt,

    // User who posted
    user: postData.user
      ? {
          id: postData.user.id,
          username: postData.user.username,
          full_name: postData.user.full_name,
          profile_pic_url: postData.user.profile_pic_url,
          is_verified: postData.user.is_verified,
        }
      : null,

    // Media files (images/videos)
    media: (postData.media || []).map((m) => ({
      id: m.id,
      media_url: m.media_url,
      thumbnail_url: m.thumbnail_url,
      small_url: m.small_url,
      medium_url: m.medium_url,
      media_type: m.media_type,
      display_order: m.display_order,
      width: m.width,
      height: m.height,
      duration: m.duration,
    })),

    // Counts
    like_count: postData.like_count || 0,
    comment_count: postData.comment_count || 0,
    save_count: postData.save_count || 0,

    // Hashtags
    hashtags: (postData.hashtags || []).map((h) => h.name),

    // Current user interaction
    is_liked: postData.is_liked || false,
    is_saved: postData.is_saved || false,
    is_own_post: currentUserId
      ? postData.user?.id === currentUserId
      : false,
  };
};

// ─── HELPER: Get post with all details ─────────────────────
const getFullPost = async (postId, currentUserId = null) => {
  const post = await Post.findOne({
    where: { id: postId, is_archived: false },
    include: [
      {
        model: User,
        as: 'user',
        attributes: [
          'id', 'username', 'full_name',
          'profile_pic_url', 'is_verified',
        ],
      },
      {
        model: PostMedia,
        as: 'media',
        order: [['display_order', 'ASC']],
      },
      {
        model: Hashtag,
        as: 'hashtags',
        attributes: ['id', 'name'],
        through: { attributes: [] }, // Don't include junction table data
      },
    ],
  });

  if (!post) return null;

  // Get counts
  const likeCount = await Like.count({ where: { post_id: postId } });
  const saveCount = await SavedPost.count({ where: { post_id: postId } });

  // Check current user interaction
  let isLiked = false;
  let isSaved = false;

  if (currentUserId) {
    isLiked = !!(await Like.findOne({
      where: { post_id: postId, user_id: currentUserId },
    }));
    isSaved = !!(await SavedPost.findOne({
      where: { post_id: postId, user_id: currentUserId },
    }));
  }

  const postData = post.toJSON();
  postData.like_count = likeCount;
  postData.save_count = saveCount;
  postData.comment_count = 0; // Will update on Day 10
  postData.is_liked = isLiked;
  postData.is_saved = isSaved;

  return formatPost(postData, currentUserId);
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/posts/
// @desc    Create a new post (1-10 images or videos)
// @access  Private
// ─────────────────────────────────────────────────────────────
const createPost = async (req, res) => {
  const transaction = await sequelize.transaction();

  try {
    const userId = req.user.id;
    const { caption, location, alt_text, comments_disabled } = req.body;

    // 1. CHECK FILES UPLOADED
    if (!req.files || req.files.length === 0) {
      await transaction.rollback();
      return errorResponse(
        res, 400,
        'Please upload at least one image or video.'
      );
    }

    if (req.files.length > 10) {
      await transaction.rollback();
      return errorResponse(
        res, 400,
        'Maximum 10 images/videos per post.'
      );
    }

    console.log(`📸 Creating post for user: ${userId}`);
    console.log(`   Files: ${req.files.length}`);

    // 2. CREATE POST IN DATABASE FIRST
    const post = await Post.create(
      {
        user_id: userId,
        caption: caption || null,
        location: location || null,
        alt_text: alt_text || null,
        comments_disabled: comments_disabled === 'true' || false,
      },
      { transaction }
    );

    console.log(`✅ Post created: ${post.id}`);

    // 3. UPLOAD EACH FILE TO CLOUDINARY
    const mediaRecords = [];

    for (let i = 0; i < req.files.length; i++) {
      const file = req.files[i];
      console.log(`   Uploading file ${i + 1}/${req.files.length}...`);

      const uploadResult = await uploadPostMedia(
        file.buffer,
        file.mimetype,
        userId,
        i
      );

      mediaRecords.push({
        post_id: post.id,
        media_url: uploadResult.url,
        thumbnail_url: uploadResult.thumbnail_url,
        small_url: uploadResult.thumbnail_url,   // 300px
        medium_url: uploadResult.medium_url,      // 600px
        media_type: uploadResult.media_type,
        cloudinary_public_id: uploadResult.public_id,
        display_order: i,
        width: uploadResult.width,
        height: uploadResult.height,
        duration: uploadResult.duration,
      });
    }

    // 4. SAVE MEDIA RECORDS TO DATABASE
    await PostMedia.bulkCreate(mediaRecords, { transaction });
    console.log(`✅ ${mediaRecords.length} media files saved`);

    // 5. EXTRACT AND SAVE HASHTAGS
    if (caption) {
      await saveHashtagsForPost(post.id, caption, transaction);
    }

    // 6. COMMIT TRANSACTION
    await transaction.commit();
    console.log(`✅ Post creation complete: ${post.id}`);

    if (caption) {
      processMentions(caption, userId, post.id);
    }

    // 7. GET FULL POST DATA FOR RESPONSE
    const fullPost = await getFullPost(post.id, userId);

    return successResponse(
      res, 201,
      'Post created successfully! 🎉',
      { post: fullPost }
    );

  } catch (error) {
    await transaction.rollback();
    console.error('❌ Create post error:', error);
    return errorResponse(res, 500, 'Failed to create post. Please try again.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/posts/feed
// @desc    Get home feed (posts from followed users)
// @access  Private
// ─────────────────────────────────────────────────────────────
const getFeed = async (req, res) => {
  try {
    const currentUserId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 12;
    const offset = (page - 1) * limit;

    const following = await Follower.findAll({
      where: {
        follower_id: currentUserId,
        status: 'accepted',
      },
      attributes: ['following_id'],
      raw: true,
    });

    const blockedRelations = await Block.findAll({
      where: {
        [Op.or]: [
          { blocker_id: currentUserId },
          { blocked_id: currentUserId },
        ],
      },
      attributes: ['blocker_id', 'blocked_id'],
      raw: true,
    });

    const blockedUserIds = blockedRelations.map((block) =>
      block.blocker_id === currentUserId ? block.blocked_id : block.blocker_id
    );

    const followingIds = following.map((follow) => follow.following_id);
    const feedUserIds = [...followingIds, currentUserId];
    const hasFollowedFeed = followingIds.length > 0;
    const whereClause = {
      is_archived: false,
      ...(hasFollowedFeed
        ? { user_id: { [Op.in]: feedUserIds } }
        : {
            user_id: {
              [Op.notIn]: [currentUserId, ...blockedUserIds],
            },
          }),
    };

    const { count, rows: posts } = await Post.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: User,
          as: 'user',
          attributes: [
            'id', 'username', 'full_name',
            'profile_pic_url', 'is_verified',
          ],
          ...(!hasFollowedFeed && { where: { is_private: false } }),
        },
        {
          model: PostMedia,
          as: 'media',
          order: [['display_order', 'ASC']],
        },
        {
          model: Hashtag,
          as: 'hashtags',
          attributes: ['id', 'name'],
          through: { attributes: [] },
        },
      ],
      order: [['created_at', 'DESC']],
      limit,
      offset,
      distinct: true,
    });

    const postIds = posts.map((p) => p.id);

    if (postIds.length === 0) {
      return paginatedResponse(
        res,
        'Feed fetched successfully',
        [],
        { page, totalPages: 0, totalItems: 0, limit }
      );
    }

    const [
      likeCounts,
      saveCounts,
      commentCounts,
      userLikes,
      userSaves,
    ] = await Promise.all([
      Like.findAll({
        where: { post_id: { [Op.in]: postIds } },
        attributes: [
          'post_id',
          [sequelize.fn('COUNT', sequelize.col('id')), 'count'],
        ],
        group: ['post_id'],
        raw: true,
      }),
      SavedPost.findAll({
        where: { post_id: { [Op.in]: postIds } },
        attributes: [
          'post_id',
          [sequelize.fn('COUNT', sequelize.col('id')), 'count'],
        ],
        group: ['post_id'],
        raw: true,
      }),
      Comment.findAll({
        where: {
          post_id: { [Op.in]: postIds },
          is_hidden: false,
          parent_comment_id: null,
        },
        attributes: [
          'post_id',
          [sequelize.fn('COUNT', sequelize.col('id')), 'count'],
        ],
        group: ['post_id'],
        raw: true,
      }),
      Like.findAll({
        where: { user_id: currentUserId, post_id: { [Op.in]: postIds } },
        attributes: ['post_id'],
        raw: true,
      }),
      SavedPost.findAll({
        where: { user_id: currentUserId, post_id: { [Op.in]: postIds } },
        attributes: ['post_id'],
        raw: true,
      }),
    ]);

    const likeCountMap = {};
    likeCounts.forEach((l) => { likeCountMap[l.post_id] = parseInt(l.count); });

    const saveCountMap = {};
    saveCounts.forEach((s) => { saveCountMap[s.post_id] = parseInt(s.count); });

    const commentCountMap = {};
    commentCounts.forEach((comment) => {
      commentCountMap[comment.post_id] = parseInt(comment.count);
    });

    const likedSet = new Set(userLikes.map((l) => l.post_id));
    const savedSet = new Set(userSaves.map((s) => s.post_id));

    const formattedPosts = posts.map((post) => {
      const postData = post.toJSON();
      postData.like_count = likeCountMap[post.id] || 0;
      postData.save_count = saveCountMap[post.id] || 0;
      postData.comment_count = commentCountMap[post.id] || 0;
      postData.is_liked = likedSet.has(post.id);
      postData.is_saved = savedSet.has(post.id);
      return formatPost(postData, currentUserId);
    });

    return paginatedResponse(
      res,
      'Feed fetched successfully',
      formattedPosts,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get feed error:', error);
    return errorResponse(res, 500, 'Failed to fetch feed.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/posts/explore
// @desc    Explore page (popular/recent posts)
// @access  Private
// ─────────────────────────────────────────────────────────────
const getExplorePosts = async (req, res) => {
  try {
    const currentUserId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 24;
    const offset = (page - 1) * limit;

    // Get posts ordered by like count (popular first)
    const posts = await Post.findAll({
      where: { is_archived: false },
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'username', 'profile_pic_url', 'is_verified'],
        },
        {
          model: PostMedia,
          as: 'media',
          // Only first media for grid view
          limit: 1,
          order: [['display_order', 'ASC']],
        },
      ],
      // Subquery to count likes
      attributes: {
        include: [
          [
            sequelize.literal(`(
              SELECT COUNT(*)
              FROM likes
              WHERE likes.post_id = "Post"."id"
            )`),
            'like_count',
          ],
        ],
      },
      order: [
        [sequelize.literal('like_count'), 'DESC'],
        ['created_at', 'DESC'],
      ],
      limit,
      offset,
    });

    // Format for grid view (simpler than feed)
    const formattedPosts = posts.map((post) => {
      const postData = post.toJSON();
      return {
        id: postData.id,
        thumbnail_url: postData.media?.[0]?.small_url
          || postData.media?.[0]?.media_url,
        media_type: postData.media?.[0]?.media_type,
        like_count: parseInt(postData.like_count) || 0,
        comment_count: 0,
        has_multiple_media: false, // Will update with real count
        user: {
          id: postData.user?.id,
          username: postData.user?.username,
        },
      };
    });

    return successResponse(res, 200, 'Explore posts fetched', {
      posts: formattedPosts,
      page,
      has_next: posts.length === limit,
    });

  } catch (error) {
    console.error('❌ Get explore error:', error);
    return errorResponse(res, 500, 'Failed to fetch explore posts.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/posts/:id
// @desc    Get single post details
// @access  Private
// ─────────────────────────────────────────────────────────────
const getPost = async (req, res) => {
  try {
    const { id } = req.params;
    const currentUserId = req.user.id;

    const post = await getFullPost(id, currentUserId);

    if (!post) {
      return errorResponse(res, 404, 'Post not found.');
    }

    return successResponse(res, 200, 'Post fetched successfully', { post });

  } catch (error) {
    console.error('❌ Get post error:', error);
    return errorResponse(res, 500, 'Failed to fetch post.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/posts/user/:userId
// @desc    Get all posts by a user
// @access  Private
// ─────────────────────────────────────────────────────────────
const getUserPosts = async (req, res) => {
  try {
    const { userId } = req.params;
    const currentUserId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 12;
    const offset = (page - 1) * limit;

    const { count, rows: posts } = await Post.findAndCountAll({
      where: { user_id: userId, is_archived: false },
      include: [
        {
          model: PostMedia,
          as: 'media',
          limit: 1,
          order: [['display_order', 'ASC']],
        },
      ],
      attributes: {
        include: [
          [
            sequelize.literal(`(
              SELECT COUNT(*) FROM likes WHERE likes.post_id = "Post"."id"
            )`),
            'like_count',
          ],
        ],
      },
      order: [['created_at', 'DESC']],
      limit,
      offset,
      distinct: true,
    });

    const formattedPosts = posts.map((post) => {
      const p = post.toJSON();
      return {
        id: p.id,
        thumbnail_url: p.media?.[0]?.small_url || p.media?.[0]?.media_url,
        media_type: p.media?.[0]?.media_type || 'image',
        like_count: parseInt(p.like_count) || 0,
        comment_count: 0,
        created_at: p.created_at,
      };
    });

    return paginatedResponse(
      res,
      'User posts fetched',
      formattedPosts,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get user posts error:', error);
    return errorResponse(res, 500, 'Failed to fetch user posts.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   PUT /api/v1/posts/:id
// @desc    Edit post caption/location
// @access  Private (own post only)
// ─────────────────────────────────────────────────────────────
const updatePost = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const { caption, location, alt_text, comments_disabled } = req.body;

    const post = await Post.findByPk(id);

    if (!post) {
      return errorResponse(res, 404, 'Post not found.');
    }

    // Only post owner can edit
    if (post.user_id !== userId) {
      return errorResponse(
        res, 403,
        'You can only edit your own posts.'
      );
    }

    // Update fields
    const updateData = {};
    if (caption !== undefined) updateData.caption = caption;
    if (location !== undefined) updateData.location = location || null;
    if (alt_text !== undefined) updateData.alt_text = alt_text || null;
    if (comments_disabled !== undefined) {
      updateData.comments_disabled = Boolean(comments_disabled);
    }

    await post.update(updateData);

    // Re-process hashtags if caption changed
    if (caption !== undefined) {
      await removeHashtagsForPost(id);
      if (caption) await saveHashtagsForPost(id, caption);
    }

    const updatedPost = await getFullPost(id, userId);

    return successResponse(
      res, 200,
      'Post updated successfully',
      { post: updatedPost }
    );

  } catch (error) {
    console.error('❌ Update post error:', error);
    return errorResponse(res, 500, 'Failed to update post.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/posts/:id
// @desc    Delete a post
// @access  Private (own post only)
// ─────────────────────────────────────────────────────────────
const deletePost = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const post = await Post.findOne({
      where: { id },
      include: [{ model: PostMedia, as: 'media' }],
    });

    if (!post) {
      return errorResponse(res, 404, 'Post not found.');
    }

    if (post.user_id !== userId) {
      return errorResponse(
        res, 403,
        'You can only delete your own posts.'
      );
    }

    // Delete media from Cloudinary
    for (const media of post.media) {
      if (media.cloudinary_public_id) {
        await deleteFromCloudinary(media.cloudinary_public_id);
      }
    }

    // Remove hashtag links and decrement counts
    await removeHashtagsForPost(id);

    // Delete post (cascade deletes media, likes, saves)
    await post.destroy();

    console.log(`🗑️  Post deleted: ${id}`);

    return successResponse(
      res, 200,
      'Post deleted successfully.',
      {}
    );

  } catch (error) {
    console.error('❌ Delete post error:', error);
    return errorResponse(res, 500, 'Failed to delete post.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/posts/:id/like
// @desc    Like a post
// @access  Private
// ─────────────────────────────────────────────────────────────
const likePost = async (req, res) => {
  try {
    const { id: postId } = req.params;
    const userId = req.user.id;

    // Check post exists
    const post = await Post.findByPk(postId);
    if (!post) {
      return errorResponse(res, 404, 'Post not found.');
    }

    // Try to create like
    const [like, created] = await Like.findOrCreate({
      where: { user_id: userId, post_id: postId },
    });

    if (!created) {
      return errorResponse(res, 400, 'You already liked this post.');
    }

    notifyLike(userId, postId);

    // Get updated like count
    const likeCount = await Like.count({ where: { post_id: postId } });

    console.log(`❤️  Post liked: ${postId} by ${userId}`);

    return successResponse(res, 200, 'Post liked! ❤️', {
      post_id: postId,
      like_count: likeCount,
      is_liked: true,
    });

  } catch (error) {
    console.error('❌ Like post error:', error);
    return errorResponse(res, 500, 'Failed to like post.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/posts/:id/like
// @desc    Unlike a post
// @access  Private
// ─────────────────────────────────────────────────────────────
const unlikePost = async (req, res) => {
  try {
    const { id: postId } = req.params;
    const userId = req.user.id;

    const deleted = await Like.destroy({
      where: { user_id: userId, post_id: postId },
    });

    if (deleted === 0) {
      return errorResponse(res, 400, 'You have not liked this post.');
    }

    const likeCount = await Like.count({ where: { post_id: postId } });

    return successResponse(res, 200, 'Post unliked.', {
      post_id: postId,
      like_count: likeCount,
      is_liked: false,
    });

  } catch (error) {
    console.error('❌ Unlike post error:', error);
    return errorResponse(res, 500, 'Failed to unlike post.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/posts/:id/likes
// @desc    Get list of users who liked a post
// @access  Private
// ─────────────────────────────────────────────────────────────
const getPostLikers = async (req, res) => {
  try {
    const { id: postId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const post = await Post.findByPk(postId);
    if (!post) {
      return errorResponse(res, 404, 'Post not found.');
    }

    const { count, rows: likes } = await Like.findAndCountAll({
      where: { post_id: postId },
      include: [
        {
          model: User,
          as: 'user',
          attributes: [
            'id', 'username', 'full_name',
            'profile_pic_url', 'is_verified',
          ],
        },
      ],
      order: [['created_at', 'DESC']],
      limit,
      offset,
    });

    const users = likes.map((like) => ({
      id: like.user.id,
      username: like.user.username,
      full_name: like.user.full_name,
      profile_pic_url: like.user.profile_pic_url,
      is_verified: like.user.is_verified,
      is_following: false, // Will update Day 11
    }));

    return paginatedResponse(
      res,
      'Post likers fetched',
      users,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get post likers error:', error);
    return errorResponse(res, 500, 'Failed to fetch post likers.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/posts/:id/save
// @desc    Save/bookmark a post
// @access  Private
// ─────────────────────────────────────────────────────────────
const savePost = async (req, res) => {
  try {
    const { id: postId } = req.params;
    const userId = req.user.id;

    const post = await Post.findByPk(postId);
    if (!post) {
      return errorResponse(res, 404, 'Post not found.');
    }

    const [save, created] = await SavedPost.findOrCreate({
      where: { user_id: userId, post_id: postId },
    });

    if (!created) {
      return errorResponse(res, 400, 'Post already saved.');
    }

    return successResponse(res, 200, 'Post saved! 🔖', {
      post_id: postId,
      is_saved: true,
    });

  } catch (error) {
    console.error('❌ Save post error:', error);
    return errorResponse(res, 500, 'Failed to save post.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/posts/:id/save
// @desc    Unsave/remove bookmark
// @access  Private
// ─────────────────────────────────────────────────────────────
const unsavePost = async (req, res) => {
  try {
    const { id: postId } = req.params;
    const userId = req.user.id;

    const deleted = await SavedPost.destroy({
      where: { user_id: userId, post_id: postId },
    });

    if (deleted === 0) {
      return errorResponse(res, 400, 'Post was not saved.');
    }

    return successResponse(res, 200, 'Post removed from saved.', {
      post_id: postId,
      is_saved: false,
    });

  } catch (error) {
    console.error('❌ Unsave post error:', error);
    return errorResponse(res, 500, 'Failed to unsave post.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/users/saved
// @desc    Get all saved posts for current user
// @access  Private
// ─────────────────────────────────────────────────────────────
const getSavedPosts = async (req, res) => {
  try {
    const userId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 12;
    const offset = (page - 1) * limit;

    const { count, rows: savedPosts } = await SavedPost.findAndCountAll({
      where: { user_id: userId },
      include: [
        {
          model: Post,
          as: 'post',
          where: { is_archived: false },
          include: [
            {
              model: PostMedia,
              as: 'media',
              limit: 1,
              order: [['display_order', 'ASC']],
            },
            {
              model: User,
              as: 'user',
              attributes: ['id', 'username', 'profile_pic_url'],
            },
          ],
        },
      ],
      order: [['created_at', 'DESC']],
      limit,
      offset,
    });

    const posts = savedPosts
      .filter((sp) => sp.post) // Filter out deleted posts
      .map((sp) => {
        const p = sp.post.toJSON();
        return {
          id: p.id,
          thumbnail_url: p.media?.[0]?.small_url || p.media?.[0]?.media_url,
          media_type: p.media?.[0]?.media_type || 'image',
          user: {
            id: p.user?.id,
            username: p.user?.username,
          },
          saved_at: sp.createdAt,
        };
      });

    return paginatedResponse(
      res,
      'Saved posts fetched',
      posts,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get saved posts error:', error);
    return errorResponse(res, 500, 'Failed to fetch saved posts.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/posts/hashtag/:tag
// @desc    Get posts by hashtag
// @access  Private
// ─────────────────────────────────────────────────────────────
const getPostsByHashtag = async (req, res) => {
  try {
    const { tag } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 12;
    const offset = (page - 1) * limit;

    // Find hashtag
    const hashtag = await Hashtag.findOne({
      where: { name: tag.toLowerCase() },
    });

    if (!hashtag) {
      return successResponse(res, 200, 'Hashtag not found', {
        hashtag: tag,
        post_count: 0,
        posts: [],
      });
    }

    // Get posts with this hashtag
    const posts = await Post.findAll({
      where: { is_archived: false },
      include: [
        {
          model: Hashtag,
          as: 'hashtags',
          where: { name: tag.toLowerCase() },
          through: { attributes: [] },
        },
        {
          model: PostMedia,
          as: 'media',
          limit: 1,
          order: [['display_order', 'ASC']],
        },
        {
          model: User,
          as: 'user',
          attributes: ['id', 'username', 'profile_pic_url'],
        },
      ],
      order: [['created_at', 'DESC']],
      limit,
      offset,
    });

    const formattedPosts = posts.map((post) => {
      const p = post.toJSON();
      return {
        id: p.id,
        thumbnail_url: p.media?.[0]?.small_url || p.media?.[0]?.media_url,
        media_type: p.media?.[0]?.media_type || 'image',
        user: {
          id: p.user?.id,
          username: p.user?.username,
          profile_pic_url: p.user?.profile_pic_url,
        },
      };
    });

    return successResponse(res, 200, `Posts for #${tag}`, {
      hashtag: hashtag.name,
      post_count: hashtag.post_count,
      posts: formattedPosts,
      page,
      has_next: posts.length === limit,
    });

  } catch (error) {
    console.error('❌ Get hashtag posts error:', error);
    return errorResponse(res, 500, 'Failed to fetch hashtag posts.');
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
