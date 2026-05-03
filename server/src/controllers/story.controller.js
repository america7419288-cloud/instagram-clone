// server/src/controllers/story.controller.js

const {
  Story,
  StoryView,
  User,
  Follower,
  Block,
  StoryPoll,
  StoryQuestion,
  sequelize,
} = require('../models');
const {
  successResponse,
  errorResponse,
  paginatedResponse,
} = require('../utils/response.utils');
const {
  uploadStoryToCloudinary,
  deleteFromCloudinary,
} = require('../services/upload.service');
const { Op } = require('sequelize');

// ─── HELPER: Format story ──────────────────────────────────
const formatStory = (story, viewerId = null) => {
  const s = story.toJSON ? story.toJSON() : story;

  return {
    id: s.id,
    media_url: s.media_url,
    thumbnail_url: s.thumbnail_url,
    media_type: s.media_type,
    caption: s.caption,
    link: s.link,
    audience: s.audience,
    width: s.width,
    height: s.height,
    duration: s.duration,
    expires_at: s.expires_at,
    created_at: s.created_at || s.createdAt,

    // User who posted
    user: s.user
      ? {
          id: s.user.id,
          username: s.user.username,
          full_name: s.user.full_name,
          profile_pic_url: s.user.profile_pic_url,
          is_verified: s.user.is_verified,
        }
      : null,

    // View stats
    view_count: s.view_count || 0,
    is_viewed: s.is_viewed || false,
    is_own_story: viewerId ? s.user_id === viewerId : false,

    // Stickers
    poll: s.poll
      ? {
          id: s.poll.id,
          question: s.poll.question,
          optionA: s.poll.optionA || s.poll.option_a,
          optionB: s.poll.optionB || s.poll.option_b,
          votesA: s.poll.votesA || s.poll.votes_a || 0,
          votesB: s.poll.votesB || s.poll.votes_b || 0,
          totalVotes: (s.poll.votesA || s.poll.votes_a || 0) + (s.poll.votesB || s.poll.votes_b || 0),
          // Positioning
          x: s.poll.x || 0.5,
          y: s.poll.y || 0.5,
          width: s.poll.width || 0,
          height: s.poll.height || 0,
          rotation: s.poll.rotation || 0,
        }
      : null,
    question: s.question
      ? {
          id: s.question.id,
          question: s.question.question,
          answersCount: s.question.answersCount || s.question.answers_count || 0,
          // Positioning
          x: s.question.x || 0.5,
          y: s.question.y || 0.5,
          width: s.question.width || 0,
          height: s.question.height || 0,
          rotation: s.question.rotation || 0,
        }
      : null,
  };
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/stories/
// @desc    Create a new story
// @access  Private
// ─────────────────────────────────────────────────────────────
const createStory = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      caption,
      link,
      audience: rawAudience = 'followers',
      pollQuestion,
      optionA,
      optionB,
      questionText,
      // Positioning
      stickerX,
      stickerY,
      stickerWidth,
      stickerHeight,
      stickerRotation,
    } = req.body;

    // Normalize audience: 'all' -> 'followers'
    const audience = rawAudience === 'all' ? 'followers' : rawAudience;

    // 1. CHECK FILE UPLOADED
    if (!req.file) {
      return errorResponse(
        res,
        400,
        'Please upload an image or video for your story.'
      );
    }

    // 2. VALIDATE AUDIENCE
    const validAudiences = ['followers', 'close_friends'];
    if (!validAudiences.includes(audience)) {
      return errorResponse(res, 400, 'Invalid audience value.');
    }

    console.log(`📖 Creating story for user: ${userId}`);

    // 3. UPLOAD TO CLOUDINARY
    const uploadResult = await uploadStoryToCloudinary(
      req.file.buffer,
      req.file.mimetype
    );

    // 4. CREATE STORY IN DATABASE
    const story = await Story.create({
      user_id: userId,
      media_url:            uploadResult.url,
      thumbnail_url:        uploadResult.thumbnailUrl,
      media_type:           uploadResult.mediaType,
      cloudinary_public_id: uploadResult.publicId,
      caption:              caption || null,
      link:                 link || null,
      audience,
      width:                uploadResult.width || 1080,
      height:               uploadResult.height || 1920,
      duration:             uploadResult.duration || null,
      // Auto-set expiry 24 hours from now
      expires_at:           new Date(Date.now() + 24 * 60 * 60 * 1000),
    });

    // 4.1 CREATE STICKERS IF PROVIDED
    if (pollQuestion) {
      await StoryPoll.create({
        storyId:  story.id,
        question: pollQuestion,
        optionA:  optionA || 'Yes',
        optionB:  optionB || 'No',
        x:        stickerX || 0.5,
        y:        stickerY || 0.5,
        width:    stickerWidth || 0,
        height:   stickerHeight || 0,
        rotation: stickerRotation || 0,
      });
    }

    if (questionText) {
      await StoryQuestion.create({
        storyId:  story.id,
        question: questionText,
        x:        stickerX || 0.5,
        y:        stickerY || 0.5,
        width:    stickerWidth || 0,
        height:   stickerHeight || 0,
        rotation: stickerRotation || 0,
      });
    }

    // 5. GET STORY WITH USER DATA
    const fullStory = await Story.findByPk(story.id, {
      include: [
        {
          model: User,
          as: 'user',
          attributes: [
            'id', 'username', 'full_name',
            'profile_pic_url', 'is_verified',
          ],
        },
        { model: StoryPoll, as: 'poll' },
        { model: StoryQuestion, as: 'question' },
      ],
    });

    console.log(`✅ Story created: ${story.id}`);

    return successResponse(
      res,
      201,
      'Story posted successfully! 📖',
      { story: formatStory(fullStory, userId) }
    );

  } catch (error) {
    console.error('❌ Create story error:', error);
    return errorResponse(
      res,
      500,
      'Failed to create story. Please try again.'
    );
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/stories/feed
// @desc    Get stories from followed users (grouped by user)
// @access  Private
// ─────────────────────────────────────────────────────────────
const getStoryFeed = async (req, res) => {
  try {
    const currentUserId = req.user.id;
    const now = new Date();

    // 1. GET FOLLOWED USER IDs
    const following = await Follower.findAll({
      where: {
        follower_id: currentUserId,
        status: 'accepted',
      },
      attributes: ['following_id'],
      raw: true,
    });

    const followingIds = following.map((f) => f.following_id);
    // Include own stories in feed
    const feedUserIds = [currentUserId, ...followingIds];

    // 2. GET BLOCKED USERS
    const blocks = await Block.findAll({
      where: {
        [Op.or]: [
          { blocker_id: currentUserId },
          { blocked_id: currentUserId },
        ],
      },
      attributes: ['blocker_id', 'blocked_id'],
      raw: true,
    });

    const blockedIds = blocks.map((b) =>
      b.blocker_id === currentUserId
        ? b.blocked_id
        : b.blocker_id
    );

    // Exclude blocked users from feed
    const filteredUserIds = feedUserIds.filter(
      (id) => !blockedIds.includes(id)
    );

    if (filteredUserIds.length === 0) {
      return successResponse(res, 200, 'No stories yet', {
        users: [],
        total_users: 0,
      });
    }

    // 3. GET ALL ACTIVE STORIES FROM THESE USERS
    const stories = await Story.findAll({
      where: {
        user_id: { [Op.in]: filteredUserIds },
        expires_at: { [Op.gt]: now }, // Not expired
        audience: 'followers',        // Public stories
      },
      include: [
        {
          model: User,
          as: 'user',
          attributes: [
            'id', 'username', 'full_name',
            'profile_pic_url', 'is_verified',
          ],
        },
        { model: StoryPoll, as: 'poll' },
        { model: StoryQuestion, as: 'question' },
      ],
      order: [['created_at', 'ASC']],
    });

    if (stories.length === 0) {
      return successResponse(res, 200, 'No stories yet', {
        users: [],
        total_users: 0,
      });
    }

    // 4. GET WHICH STORIES CURRENT USER HAS VIEWED
    const storyIds = stories.map((s) => s.id);

    const viewedStories = await StoryView.findAll({
      where: {
        viewer_id: currentUserId,
        story_id: { [Op.in]: storyIds },
      },
      attributes: ['story_id'],
      raw: true,
    });

    const viewedStoryIds = new Set(
      viewedStories.map((v) => v.story_id)
    );

    // 5. GROUP STORIES BY USER
    const userStoriesMap = {};

    for (const story of stories) {
      const userId = story.user_id;
      if (!userStoriesMap[userId]) {
        userStoriesMap[userId] = {
          user: {
            id: story.user.id,
            username: story.user.username,
            full_name: story.user.full_name,
            profile_pic_url: story.user.profile_pic_url,
            is_verified: story.user.is_verified,
          },
          stories: [],
          has_unseen: false,  // Does user have unseen stories?
          latest_story_at: null,
          is_own: story.user_id === currentUserId,
        };
      }

      const isViewed = viewedStoryIds.has(story.id);
      if (!isViewed) {
        userStoriesMap[userId].has_unseen = true;
      }

      userStoriesMap[userId].stories.push({
        ...formatStory(story, currentUserId),
        is_viewed: isViewed,
      });

      // Track latest story time
      if (
        !userStoriesMap[userId].latest_story_at ||
        story.createdAt > userStoriesMap[userId].latest_story_at
      ) {
        userStoriesMap[userId].latest_story_at = story.createdAt;
      }
    }

    // 6. SORT: Own stories first, then unseen, then seen
    const usersWithStories = Object.values(userStoriesMap).sort(
      (a, b) => {
        // Own story always first
        if (a.is_own) return -1;
        if (b.is_own) return 1;
        // Unseen stories before seen
        if (a.has_unseen && !b.has_unseen) return -1;
        if (!a.has_unseen && b.has_unseen) return 1;
        // Most recent last story first
        return (
          new Date(b.latest_story_at) -
          new Date(a.latest_story_at)
        );
      }
    );

    return successResponse(res, 200, 'Story feed fetched', {
      users: usersWithStories,
      total_users: usersWithStories.length,
    });

  } catch (error) {
    console.error('❌ Get story feed error:', error);
    return errorResponse(res, 500, 'Failed to fetch stories.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/stories/my
// @desc    Get own stories (including expired)
// @access  Private
// ─────────────────────────────────────────────────────────────
const getMyStories = async (req, res) => {
  try {
    const userId = req.user.id;
    const includeExpired = req.query.include_expired === 'true';
    const now = new Date();

    const whereClause = {
      user_id: userId,
      ...(includeExpired ? {} : { expires_at: { [Op.gt]: now } }),
    };

    const stories = await Story.findAll({
      where: whereClause,
      include: [
        {
          model: StoryView,
          as: 'views',
          attributes: ['id'],
        },
        { model: StoryPoll, as: 'poll' },
        { model: StoryQuestion, as: 'question' },
      ],
      order: [['created_at', 'DESC']],
    });

    const formattedStories = stories.map((story) => ({
      ...formatStory(story, userId),
      is_expired: story.expires_at < now,
    }));

    return successResponse(res, 200, 'Your stories fetched', {
      stories: formattedStories,
      total: formattedStories.length,
      active_count: formattedStories.filter((s) => !s.is_expired)
        .length,
    });

  } catch (error) {
    console.error('❌ Get my stories error:', error);
    return errorResponse(res, 500, 'Failed to fetch your stories.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/stories/user/:userId
// @desc    Get stories by a specific user
// @access  Private
// ─────────────────────────────────────────────────────────────
const getUserStories = async (req, res) => {
  try {
    const { userId } = req.params;
    const currentUserId = req.user.id;
    const now = new Date();

    // Check if target user exists
    const targetUser = await User.findByPk(userId);
    if (!targetUser) {
      return errorResponse(res, 404, 'User not found.');
    }

    // Check blocked
    const blockExists = await Block.findOne({
      where: {
        [Op.or]: [
          { blocker_id: currentUserId, blocked_id: userId },
          { blocker_id: userId, blocked_id: currentUserId },
        ],
      },
    });

    if (blockExists) {
      return errorResponse(res, 404, 'User not found.');
    }

    // Get active stories
    const stories = await Story.findAll({
      where: {
        user_id: userId,
        expires_at: { [Op.gt]: now },
        audience: 'followers',
      },
      include: [
        {
          model: User,
          as: 'user',
          attributes: [
            'id', 'username', 'full_name',
            'profile_pic_url', 'is_verified',
          ],
        },
        { model: StoryPoll, as: 'poll' },
        { model: StoryQuestion, as: 'question' },
      ],
      order: [['created_at', 'ASC']],
    });

    // Get views for these stories by current user
    const storyIds = stories.map((s) => s.id);
    const views = await StoryView.findAll({
      where: {
        viewer_id: currentUserId,
        story_id: { [Op.in]: storyIds },
      },
      attributes: ['story_id'],
      raw: true,
    });

    const viewedIds = new Set(views.map((v) => v.story_id));

    const formattedStories = stories.map((story) =>
      formatStory(
        {
          ...story.toJSON(),
          is_viewed: viewedIds.has(story.id),
          view_count: 0, // Owner only
        },
        currentUserId
      )
    );

    return successResponse(res, 200, 'User stories fetched', {
      user: {
        id: targetUser.id,
        username: targetUser.username,
        full_name: targetUser.full_name,
        profile_pic_url: targetUser.profile_pic_url,
        is_verified: targetUser.is_verified,
      },
      stories: formattedStories,
      total: formattedStories.length,
    });

  } catch (error) {
    console.error('❌ Get user stories error:', error);
    return errorResponse(res, 500, 'Failed to fetch stories.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/stories/:id/view
// @desc    Mark a story as viewed
// @access  Private
// ─────────────────────────────────────────────────────────────
const viewStory = async (req, res) => {
  try {
    const { id: storyId } = req.params;
    const viewerId = req.user.id;
    const now = new Date();

    // Check story exists and not expired
    const story = await Story.findOne({
      where: {
        id: storyId,
        expires_at: { [Op.gt]: now },
      },
    });

    if (!story) {
      return errorResponse(
        res,
        404,
        'Story not found or has expired.'
      );
    }

    // Don't count own story views
    if (story.user_id === viewerId) {
      return successResponse(res, 200, 'Own story view not tracked', {
        story_id: storyId,
      });
    }

    // Create view (ignore if already viewed - unique constraint)
    await StoryView.findOrCreate({
      where: { story_id: storyId, viewer_id: viewerId },
      defaults: { viewed_at: new Date() },
    });

    // Get updated view count
    const viewCount = await StoryView.count({
      where: { story_id: storyId },
    });

    return successResponse(res, 200, 'Story marked as viewed', {
      story_id: storyId,
      view_count: viewCount,
    });

  } catch (error) {
    console.error('❌ View story error:', error);
    return errorResponse(res, 500, 'Failed to mark story as viewed.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/stories/:id/viewers
// @desc    Get list of users who viewed a story (owner only)
// @access  Private
// ─────────────────────────────────────────────────────────────
const getStoryViewers = async (req, res) => {
  try {
    const { id: storyId } = req.params;
    const currentUserId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;

    // Check story exists and belongs to current user
    const story = await Story.findByPk(storyId);

    if (!story) {
      return errorResponse(res, 404, 'Story not found.');
    }

    if (story.user_id !== currentUserId) {
      return errorResponse(
        res,
        403,
        'You can only see viewers of your own stories.'
      );
    }

    // Get viewers
    const { count, rows: views } = await StoryView.findAndCountAll({
      where: { story_id: storyId },
      include: [
        {
          model: User,
          as: 'viewer',
          attributes: [
            'id', 'username', 'full_name',
            'profile_pic_url', 'is_verified',
          ],
        },
      ],
      order: [['viewed_at', 'DESC']],
      limit,
      offset,
    });

    const viewers = views.map((view) => ({
      id: view.viewer.id,
      username: view.viewer.username,
      full_name: view.viewer.full_name,
      profile_pic_url: view.viewer.profile_pic_url,
      is_verified: view.viewer.is_verified,
      viewed_at: view.viewed_at,
    }));

    return paginatedResponse(
      res,
      'Story viewers fetched',
      viewers,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get story viewers error:', error);
    return errorResponse(
      res,
      500,
      'Failed to fetch story viewers.'
    );
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/stories/:id
// @desc    Delete own story
// @access  Private
// ─────────────────────────────────────────────────────────────
const deleteStory = async (req, res) => {
  try {
    const { id: storyId } = req.params;
    const userId = req.user.id;

    const story = await Story.findByPk(storyId);

    if (!story) {
      return errorResponse(res, 404, 'Story not found.');
    }

    // Only owner can delete
    if (story.user_id !== userId) {
      return errorResponse(
        res,
        403,
        'You can only delete your own stories.'
      );
    }

    // Delete from Cloudinary
    if (story.cloudinary_public_id) {
      await deleteFromCloudinary(story.cloudinary_public_id);
      console.log(
        `☁️ Story media deleted from Cloudinary: ${story.cloudinary_public_id}`
      );
    }

    // Delete from database (cascade deletes views)
    await story.destroy();

    console.log(`🗑️  Story deleted: ${storyId}`);

    return successResponse(
      res,
      200,
      'Story deleted successfully.',
      { deleted_story_id: storyId }
    );

  } catch (error) {
    console.error('❌ Delete story error:', error);
    return errorResponse(res, 500, 'Failed to delete story.');
  }
};

// ─────────────────────────────────────────────────────
// GET STORY ARCHIVE
// Stories that have expired but belong to the current user
// GET /api/v1/stories/archive
// ─────────────────────────────────────────────────────
const getStoryArchive = async (req, res) => {
  try {
    const userId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    // ─── Get EXPIRED stories ──────────
    const stories = await Story.findAll({
      where: {
        user_id: userId,
        expires_at: { [Op.lt]: new Date() }, // expired
      },
      order: [['created_at', 'DESC']],
      limit,
      offset,
    });

    const formatted = stories.map((s) => ({
      id: s.id,
      media_url: s.media_url,
      media_type: s.media_type,
      thumbnail_url: s.thumbnail_url,
      caption: s.caption,
      created_at: s.createdAt || s.created_at,
      expires_at: s.expires_at,
    }));

    return res.json({
      success: true,
      message: 'Story archive loaded',
      data: formatted,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('❌ getStoryArchive error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to load story archive',
      timestamp: new Date().toISOString(),
    });
  }
};

module.exports = {
  createStory,
  getStoryFeed,
  getMyStories,
  getUserStories,
  viewStory,
  getStoryViewers,
  deleteStory,
  getStoryArchive,
};
