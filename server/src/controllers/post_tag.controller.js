// server/src/controllers/post_tag.controller.js

const { v4: uuidv4 }  = require('uuid');
const { Op }          = require('sequelize');
const {
  Post,
  PostTag,
  User,
  PostMedia,
  Like,
  SavedPost,
}                     = require('../models');
const {
  successResponse,
  errorResponse,
}                     = require('../utils/response.utils');
const {
  createNotification,
}                     = require('../services/notification.service');

// ─────────────────────────────────────────────────────
// ADD TAGS TO POST
// POST /api/posts/:postId/tags
// body: { tags: [{ userId, xPosition, yPosition, mediaIndex }] }
// ─────────────────────────────────────────────────────
const addTags = async (req, res) => {
  try {
    const { postId }  = req.params;
    const currentUserId = req.user.id;
    const { tags }    = req.body;

    // ─── Validate ─────────────────────────────────────
    if (!tags || !Array.isArray(tags)) {
      return errorResponse(res, 400, 'tags must be an array');
    }

    if (tags.length > 20) {
      return errorResponse(res, 400, 'Maximum 20 tags per post');
    }

    // ─── Check post ownership ─────────────────────────
    const post = await Post.findOne({
      where:      { id: postId, userId: currentUserId },
      attributes: ['id', 'userId'],
    });

    if (!post) {
      return errorResponse(
        res,
        404,
        'Post not found or not yours',
      );
    }

    // ─── Remove existing tags first ───────────────────
    await PostTag.destroy({ where: { postId } });

    // ─── Validate + create new tags ───────────────────
    const created  = [];
    const notified = new Set();

    for (const tag of tags) {
      const { userId, xPosition, yPosition, mediaIndex = 0 } = tag;

      // Validate position
      if (
        xPosition == null || yPosition == null ||
        xPosition < 0 || xPosition > 1 ||
        yPosition < 0 || yPosition > 1
      ) {
        continue;
      }

      // Check user exists
      const user = await User.findByPk(userId, {
        attributes: ['id', 'username'],
      });
      if (!user) continue;

      // Don't allow tagging yourself
      if (userId === currentUserId) continue;

      try {
        const postTag = await PostTag.create({
          id:         uuidv4(),
          postId,
          userId,
          xPosition,
          yPosition,
          mediaIndex: Math.max(0, Math.floor(mediaIndex)),
        });
        created.push(postTag);

        // ─── Send notification (once per user) ────────
        if (!notified.has(userId)) {
          notified.add(userId);
          await createNotification({
            recipientId: userId,
            senderId:    currentUserId,
            type:        'mention_post',
            postId,
          });
        }
      } catch (e) {
        // Skip duplicates silently
        if (!e.message?.includes('unique')) {
          console.error('Tag create error:', e.message);
        }
      }
    }

    return successResponse(
      res,
      200,
      `${created.length} tag(s) added`,
      { tagsAdded: created.length },
    );
  } catch (error) {
    console.error('❌ addTags error:', error);
    return errorResponse(res, 500, 'Failed to add tags');
  }
};

// ─────────────────────────────────────────────────────
// GET TAGS FOR POST
// GET /api/posts/:postId/tags
// ─────────────────────────────────────────────────────
const getPostTags = async (req, res) => {
  try {
    const { postId } = req.params;

    const currentUserId = req.user?.id;
    const post = await Post.findByPk(postId, { attributes: ['userId'] });

    const tags = await PostTag.findAll({
      where: {
        postId,
        [Op.or]: [
          { isAccepted: true },
          // Post owner sees pending tags
          ...(post?.userId === currentUserId ? [{}] : []),
          // Tagged user sees their own pending tag
          ...(currentUserId ? [{ userId: currentUserId }] : []),
        ],
      },
      include: [
        {
          model:      User,
          as:         'user',
          attributes: [
            'id', 'username', 'fullName',
            'profile_pic_url', 'is_verified',
          ],
        },
      ],
      order: [['createdAt', 'ASC']],
    });

    const formatted = tags.map((t) => ({
      id:         t.id,
      userId:     t.userId,
      username:   t.user?.username,
      fullName:   t.user?.fullName,
      avatar:     t.user?.profile_pic_url,
      isVerified: t.user?.is_verified || false,
      xPosition:  t.xPosition,
      yPosition:  t.yPosition,
      mediaIndex: t.mediaIndex,
      postId:     t.postId,
      isAccepted: t.isAccepted,
    }));

    return successResponse(res, 200, 'Tags loaded', formatted);
  } catch (error) {
    console.error('❌ getPostTags error:', error);
    return errorResponse(res, 500, 'Failed to get tags');
  }
};

// ─────────────────────────────────────────────────────
// REMOVE SINGLE TAG
// DELETE /api/posts/:postId/tags/:userId
// ─────────────────────────────────────────────────────
const removeTag = async (req, res) => {
  try {
    const { postId, userId } = req.params;
    const currentUserId      = req.user.id;

    // ─── Post owner OR tagged user can remove ─────────
    const post = await Post.findByPk(postId, {
      attributes: ['userId'],
    });

    const isOwner    = post?.userId === currentUserId;
    const isTagged   = userId === currentUserId;

    if (!isOwner && !isTagged) {
      return errorResponse(res, 403, 'Not authorized');
    }

    const deleted = await PostTag.destroy({
      where: { postId, userId },
    });

    if (!deleted) {
      return errorResponse(res, 404, 'Tag not found');
    }

    return successResponse(res, 200, 'Tag removed');
  } catch (error) {
    console.error('❌ removeTag error:', error);
    return errorResponse(res, 500, 'Failed to remove tag');
  }
};

// ─────────────────────────────────────────────────────
// ACCEPT TAG
// PATCH /api/posts/:postId/tags/accept
// ─────────────────────────────────────────────────────
const acceptTag = async (req, res) => {
  try {
    const { postId } = req.params;
    const userId     = req.user.id;

    const [updated] = await PostTag.update(
      { isAccepted: true },
      { where: { postId, userId } }
    );

    if (!updated) {
      return errorResponse(res, 404, 'Tag not found');
    }

    return successResponse(res, 200, 'Tag accepted');
  } catch (error) {
    console.error('❌ acceptTag error:', error);
    return errorResponse(res, 500, 'Failed to accept tag');
  }
};

// ─────────────────────────────────────────────────────
// GET POSTS WHERE USER IS TAGGED
// GET /api/users/:username/tagged-posts
// ─────────────────────────────────────────────────────
const getTaggedPosts = async (req, res) => {
  try {
    const { username }   = req.params;
    const currentUserId  = req.user?.id;
    const page           = parseInt(req.query.page)  || 1;
    const limit          = parseInt(req.query.limit) || 20;
    const offset         = (page - 1) * limit;

    // ─── Find user ────────────────────────────────────
    const user = await User.findOne({
      where:      { username },
      attributes: ['id'],
    });
    if (!user) return errorResponse(res, 404, 'User not found');

    // ─── Find all tags for this user ─────────────────
    const taggedPosts = await PostTag.findAll({
      where:      { userId: user.id, isAccepted: true },
      attributes: ['postId', 'createdAt'],
      include: [
        {
          model:   Post,
          as:      'post',
          include: [
            {
              model:      User,
              as:         'user',
              attributes: [
                'id', 'username', 'profile_pic_url', 'is_verified',
              ],
            },
            {
              model:      PostMedia,
              as:         'mediaFiles',
              attributes: [
                'id', 'url', 'thumbnailUrl', 'mediaType',
                'duration', 'order',
              ],
              separate: true,
              order:    [['order', 'ASC']],
            },
            {
              model:    Like,
              as:       'likes',
              where:    currentUserId ? { userId: currentUserId } : undefined,
              required: false,
              attributes: ['userId'],
            },
            {
              model:    SavedPost,
              as:       'saves',
              where:    currentUserId ? { userId: currentUserId } : undefined,
              required: false,
              attributes: ['userId'],
            },
          ],
        },
      ],
      order:  [['createdAt', 'DESC']],
      limit,
      offset,
    });

    const formatted = taggedPosts
      .filter((t) => t.post)
      .map((t) => _formatTaggedPost(t.post, currentUserId));

    return successResponse(res, 200, 'Tagged posts loaded', formatted);
  } catch (error) {
    console.error('❌ getTaggedPosts error:', error);
    return errorResponse(res, 500, 'Failed to load tagged posts');
  }
};

// ─── Format helper ─────────────────────────────────────
const _formatTaggedPost = (post, userId) => {
  const mediaFiles = (post.mediaFiles || [])
    .sort((a, b) => a.order - b.order)
    .map((m) => ({
      id:           m.id,
      url:          m.url,
      thumbnailUrl: m.thumbnailUrl,
      mediaType:    m.mediaType,
      duration:     m.duration,
      order:        m.order,
    }));

  return {
    id:           post.id,
    userId:       post.userId,
    username:     post.user?.username,
    userAvatar:   post.user?.profile_pic_url,
    isVerified:   post.user?.is_verified || false,
    caption:      post.caption,
    mediaFiles,
    likesCount:   post.likesCount   || 0,
    commentsCount: post.commentsCount || 0,
    isLiked:      userId ? (post.likes?.length > 0)  : false,
    isSaved:      userId ? (post.saves?.length > 0)  : false,
    coverUrl:     mediaFiles[0]?.thumbnailUrl || mediaFiles[0]?.url,
    hasVideo:     mediaFiles.some((m) => m.mediaType === 'video'),
    hasMultiple:  mediaFiles.length > 1,
    createdAt:    post.createdAt,
  };
};

module.exports = {
  addTags,
  getPostTags,
  removeTag,
  acceptTag,
  getTaggedPosts,
};
