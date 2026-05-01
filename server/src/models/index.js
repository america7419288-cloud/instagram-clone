// server/src/models/index.js

const { sequelize } = require('../config/database');

// Import all models
const User = require('./User.model');
const Post = require('./Post.model');
const PostMedia = require('./PostMedia.model');
const Like = require('./Like.model');
const Hashtag = require('./Hashtag.model');
const PostHashtag = require('./PostHashtag.model');
const SavedPost = require('./SavedPost.model');

// ─── ASSOCIATIONS ──────────────────────────────────────────
// These define relationships between tables
// Sequelize uses them to build JOIN queries

// USER → POSTS (one user has many posts)
User.hasMany(Post, {
  foreignKey: 'user_id',
  as: 'posts',
  onDelete: 'CASCADE',
});
Post.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user',
});

// POST → POST MEDIA (one post has many media files)
Post.hasMany(PostMedia, {
  foreignKey: 'post_id',
  as: 'media',
  onDelete: 'CASCADE',
});
PostMedia.belongsTo(Post, {
  foreignKey: 'post_id',
  as: 'post',
});

// POST → LIKES (one post has many likes)
Post.hasMany(Like, {
  foreignKey: 'post_id',
  as: 'likes',
  onDelete: 'CASCADE',
});
Like.belongsTo(Post, {
  foreignKey: 'post_id',
  as: 'post',
});

// USER → LIKES (one user has many likes)
User.hasMany(Like, {
  foreignKey: 'user_id',
  as: 'likes',
  onDelete: 'CASCADE',
});
Like.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user',
});

// POST ↔ HASHTAGS (many-to-many through PostHashtag)
Post.belongsToMany(Hashtag, {
  through: PostHashtag,
  foreignKey: 'post_id',
  otherKey: 'hashtag_id',
  as: 'hashtags',
});
Hashtag.belongsToMany(Post, {
  through: PostHashtag,
  foreignKey: 'hashtag_id',
  otherKey: 'post_id',
  as: 'posts',
});

// POST → SAVED (one post saved by many users)
Post.hasMany(SavedPost, {
  foreignKey: 'post_id',
  as: 'saves',
  onDelete: 'CASCADE',
});
SavedPost.belongsTo(Post, {
  foreignKey: 'post_id',
  as: 'post',
});

// USER → SAVED POSTS (one user saves many posts)
User.hasMany(SavedPost, {
  foreignKey: 'user_id',
  as: 'savedPosts',
  onDelete: 'CASCADE',
});
SavedPost.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user',
});

// ─── SYNC DATABASE ─────────────────────────────────────────
const syncDatabase = async () => {
  try {
    await sequelize.sync({ alter: true });
      console.log('DEBUG - User:', typeof User === 'function' ? 'OK' : 'BROKEN');
      console.log('DEBUG - Post:', typeof Post === 'function' ? 'OK' : 'BROKEN');
      console.log('DEBUG - PostMedia:', typeof PostMedia === 'function' ? 'OK' : 'BROKEN');
      console.log('DEBUG - Like:', typeof Like === 'function' ? 'OK' : 'BROKEN');
      console.log('DEBUG - Hashtag:', typeof Hashtag === 'function' ? 'OK' : 'BROKEN');
      console.log('DEBUG - PostHashtag:', typeof PostHashtag === 'function' ? 'OK' : 'BROKEN');
      console.log('DEBUG - SavedPost:', typeof SavedPost === 'function' ? 'OK' : 'BROKEN');

  } catch (error) {
    console.error('❌ Database sync failed:', error.message);
    throw error;
  }
};

module.exports = {
  sequelize,
  syncDatabase,
  User,
  Post,
  PostMedia,
  Like,
  Hashtag,
  PostHashtag,
  SavedPost,
};