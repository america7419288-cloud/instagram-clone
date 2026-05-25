const { SavedPost, SavedCollection, Post, User, PostMedia } = require('../models');

// GET SAVED POSTS
const getSavedPosts = async (req, res) => {
  try {
    const userId = req.user.id;
    const { collectionId, page = 1, limit = 24 } = req.query;

    const whereClause = { userId };
    if (collectionId) {
      whereClause.collectionId = collectionId;
    }

    const { count, rows: savedPosts } = await SavedPost.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: Post,
          as: 'post',
          attributes: ['id', 'caption', 'likesCount', 'commentsCount', 'created_at'],
          include: [
            {
              model: User,
              as: 'user',
              attributes: ['id', 'username', 'profile_pic_url', 'is_verified'],
            },
            {
              model: PostMedia,
              as: 'media',
              attributes: ['id', 'media_url', 'media_type', 'order'],
            }
          ]
        }
      ],
      order: [['created_at', 'DESC']],
      offset: (page - 1) * limit,
      limit: parseInt(limit),
    });

    const posts = savedPosts
      .filter(s => s.post)
      .map(s => {
        const postObj = s.post.toJSON();
        return {
          id: postObj.id,
          caption: postObj.caption,
          likeCount: postObj.likesCount,
          commentCount: postObj.commentsCount,
          created_at: postObj.created_at,
          user: postObj.user,
          media: postObj.media,
          savedAt: s.created_at,
          collectionId: s.collectionId,
        };
      });

    return res.status(200).json({
      success: true,
      data: {
        posts,
        total: count,
        page: parseInt(page),
        hasMore: page * limit < count,
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// SAVE POST
const savePost = async (req, res) => {
  try {
    const { postId } = req.params;
    const { collectionId } = req.body;
    const userId = req.user.id;

    // Check if post exists
    const post = await Post.findByPk(postId);
    if (!post) {
      return res.status(404).json({
        success: false,
        message: 'Post not found',
      });
    }

    // Check if already saved
    const existing = await SavedPost.findOne({ where: { userId, postId } });
    if (existing) {
      // If moving to different collection
      if (collectionId && existing.collectionId !== collectionId) {
        // Update old collection count
        if (existing.collectionId) {
          await SavedCollection.decrement('postCount', {
            by: 1,
            where: { id: existing.collectionId }
          });
        }
        existing.collectionId = collectionId;
        await existing.save();
        // Update new collection count
        await SavedCollection.increment('postCount', {
          by: 1,
          where: { id: collectionId }
        });
        return res.status(200).json({
          success: true,
          message: 'Moved to collection',
        });
      }
      return res.status(400).json({
        success: false,
        message: 'Post already saved',
      });
    }

    await SavedPost.create({
      userId,
      postId,
      collectionId: collectionId || null,
    });

    // Update collection count
    if (collectionId) {
      await SavedCollection.increment('postCount', {
        by: 1,
        where: { id: collectionId }
      });
    }

    return res.status(201).json({
      success: true,
      message: 'Post saved',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// UNSAVE POST
const unsavePost = async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user.id;

    const saved = await SavedPost.findOne({ where: { userId, postId } });

    if (!saved) {
      return res.status(404).json({
        success: false,
        message: 'Post not saved',
      });
    }

    // Update collection count
    if (saved.collectionId) {
      await SavedCollection.decrement('postCount', {
        by: 1,
        where: { id: saved.collectionId }
      });
    }

    await saved.destroy();

    return res.status(200).json({
      success: true,
      message: 'Post unsaved',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// GET COLLECTIONS
const getCollections = async (req, res) => {
  try {
    const userId = req.user.id;
    const collections = await SavedCollection.findAll({
      where: { userId },
      order: [['isDefault', 'DESC'], ['createdAt', 'DESC']],
    });
    return res.status(200).json({
      success: true,
      data: { collections },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// CREATE COLLECTION
const createCollection = async (req, res) => {
  try {
    const { name } = req.body;
    const userId = req.user.id;

    if (!name || name.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Collection name is required',
      });
    }

    const collection = await SavedCollection.create({
      userId,
      name: name.trim(),
    });

    return res.status(201).json({
      success: true,
      message: 'Collection created',
      data: { collection },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// UPDATE COLLECTION
const updateCollection = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, coverPostId } = req.body;

    const collection = await SavedCollection.findOne({
      where: { id, userId: req.user.id }
    });

    if (!collection) {
      return res.status(404).json({
        success: false,
        message: 'Collection not found',
      });
    }

    await collection.update({
      ...(name !== undefined && { name: name.trim() }),
      ...(coverPostId !== undefined && { coverPostId }),
    });

    return res.status(200).json({
      success: true,
      data: { collection },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// DELETE COLLECTION
const deleteCollection = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const collection = await SavedCollection.findOne({
      where: { id, userId }
    });
    if (!collection) {
      return res.status(404).json({
        success: false,
        message: 'Collection not found',
      });
    }

    if (collection.isDefault) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete default collection',
      });
    }

    // Move posts to no collection
    await SavedPost.update(
      { collectionId: null },
      { where: { userId, collectionId: id } }
    );

    await collection.destroy();

    return res.status(200).json({
      success: true,
      message: 'Collection deleted',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// ADD TO COLLECTION
const addToCollection = async (req, res) => {
  try {
    const { id, postId } = req.params;
    const userId = req.user.id;

    const [savedPost, created] = await SavedPost.findOrCreate({
      where: { userId, postId },
      defaults: { collectionId: id }
    });

    if (!created) {
      // If it already existed, update the collectionId
      if (savedPost.collectionId !== id) {
        if (savedPost.collectionId) {
          await SavedCollection.decrement('postCount', {
            by: 1,
            where: { id: savedPost.collectionId }
          });
        }
        savedPost.collectionId = id;
        await savedPost.save();
        await SavedCollection.increment('postCount', {
          by: 1,
          where: { id }
        });
      }
    } else {
      // If new, increment
      await SavedCollection.increment('postCount', {
        by: 1,
        where: { id }
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Added to collection',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// REMOVE FROM COLLECTION
const removeFromCollection = async (req, res) => {
  try {
    const { id, postId } = req.params;
    const userId = req.user.id;

    const savedPost = await SavedPost.findOne({
      where: { userId, postId, collectionId: id }
    });

    if (savedPost) {
      savedPost.collectionId = null;
      await savedPost.save();
      await SavedCollection.decrement('postCount', {
        by: 1,
        where: { id }
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Removed from collection',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

module.exports = {
  getSavedPosts,
  savePost,
  unsavePost,
  getCollections,
  createCollection,
  updateCollection,
  deleteCollection,
  addToCollection,
  removeFromCollection,
};
