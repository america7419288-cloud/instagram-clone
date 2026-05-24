const { Archive, Post, Story, PostMedia, User } = require('../models');

const getArchive = async (req, res) => {
  try {
    const userId = req.user.id;
    const { type, page = 1, limit = 24 } = req.query;

    const whereClause = { userId };
    if (type) whereClause.contentType = type;

    const { count, rows: archives } = await Archive.findAndCountAll({
      where: whereClause,
      order: [['archivedAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: parseInt(limit),
    });

    return res.status(200).json({
      success: true,
      data: {
        archived: archives,
        total: count,
        page: parseInt(page),
        hasMore: page * limit < count
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const getArchivedStories = async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 24 } = req.query;

    const archives = await Archive.findAll({
      where: { userId, contentType: 'story' },
      order: [['archivedAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: parseInt(limit),
    });

    const storyIds = archives.map(a => a.contentId);
    const stories = await Story.findAll({
      where: { id: storyIds },
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'username', 'profile_pic_url']
        }
      ]
    });

    const mappedStories = archives.map(a => {
      const story = stories.find(s => s.id === a.contentId);
      if (!story) return null;
      return {
        ...story.toJSON(),
        archivedAt: a.archivedAt,
      };
    }).filter(Boolean);

    return res.status(200).json({
      success: true,
      data: {
        stories: mappedStories,
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const getArchivedPosts = async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 24 } = req.query;

    const archives = await Archive.findAll({
      where: { userId, contentType: 'post' },
      order: [['archivedAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: parseInt(limit),
    });

    const postIds = archives.map(a => a.contentId);
    const posts = await Post.findAll({
      where: { id: postIds },
      include: [
        {
          model: PostMedia,
          as: 'media',
          attributes: ['id', 'media_url', 'media_type', 'order']
        },
        {
          model: User,
          as: 'user',
          attributes: ['id', 'username', 'profile_pic_url', 'is_verified']
        }
      ]
    });

    const mappedPosts = archives.map(a => {
      const post = posts.find(p => p.id === a.contentId);
      if (!post) return null;
      return {
        ...post.toJSON(),
        archivedAt: a.archivedAt,
      };
    }).filter(Boolean);

    return res.status(200).json({
      success: true,
      data: {
        posts: mappedPosts,
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const archiveContent = async (req, res) => {
  try {
    const { type, contentId } = req.params;
    const userId = req.user.id;

    if (!['post', 'story', 'reel'].includes(type)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid content type',
      });
    }

    const existing = await Archive.findOne({
      where: { userId, contentId, contentType: type }
    });

    if (existing) {
      return res.status(400).json({
        success: false,
        message: 'Already archived',
      });
    }

    await Archive.create({
      userId,
      contentId,
      contentType: type,
      archivedAt: new Date(),
    });

    // Hide from profile
    if (type === 'post') {
      await Post.update(
        { isArchived: true },
        { where: { id: contentId, userId } }
      );
    }

    return res.status(201).json({
      success: true,
      message: 'Content archived',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const unarchiveContent = async (req, res) => {
  try {
    const { type, contentId } = req.params;
    const userId = req.user.id;

    await Archive.destroy({
      where: { userId, contentId, contentType: type }
    });

    if (type === 'post') {
      await Post.update(
        { isArchived: false },
        { where: { id: contentId, userId } }
      );
    }

    return res.status(200).json({
      success: true,
      message: 'Content unarchived',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const clearArchive = async (req, res) => {
  try {
    const { type } = req.query;
    const userId = req.user.id;

    const whereClause = { userId };
    if (type) whereClause.contentType = type;

    // Find all posts in the archive to mark them as unarchived
    if (!type || type === 'post') {
      const archivedPosts = await Archive.findAll({
        where: { userId, contentType: 'post' }
      });
      const postIds = archivedPosts.map(a => a.contentId);
      if (postIds.length > 0) {
        await Post.update(
          { isArchived: false },
          { where: { id: postIds, userId } }
        );
      }
    }

    await Archive.destroy({ where: whereClause });

    return res.status(200).json({
      success: true,
      message: 'Archive cleared',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

module.exports = {
  getArchive,
  getArchivedStories,
  getArchivedPosts,
  archiveContent,
  unarchiveContent,
  clearArchive,
};
