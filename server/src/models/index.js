// server/src/models/index.js
// COMPLETE UPDATED FILE

const { sequelize } = require('../config/database');

// ─── IMPORT ALL MODELS ─────────────────────────────────────
const User = require('./User.model');
const Post = require('./Post.model');
const PostMedia = require('./PostMedia.model');
const Like = require('./Like.model');
const Hashtag = require('./Hashtag.model');
const PostHashtag = require('./PostHashtag.model');
const SavedPost = require('./SavedPost.model');
const Comment = require('./Comment.model');
const CommentLike = require('./CommentLike.model');
const Follower = require('./Follower.model');   // ⭐ NEW
const Block = require('./Block.model');         // ⭐ NEW

// ─── ALL ASSOCIATIONS ──────────────────────────────────────

// USER → POSTS
User.hasMany(Post, {
  foreignKey: 'user_id',
  as: 'posts',
  onDelete: 'CASCADE',
});
Post.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user',
});

// POST → POST MEDIA
Post.hasMany(PostMedia, {
  foreignKey: 'post_id',
  as: 'media',
  onDelete: 'CASCADE',
});
PostMedia.belongsTo(Post, {
  foreignKey: 'post_id',
  as: 'post',
});

// POST → LIKES
Post.hasMany(Like, {
  foreignKey: 'post_id',
  as: 'likes',
  onDelete: 'CASCADE',
});
Like.belongsTo(Post, { foreignKey: 'post_id', as: 'post' });

// USER → LIKES
User.hasMany(Like, {
  foreignKey: 'user_id',
  as: 'likes',
  onDelete: 'CASCADE',
});
Like.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// POST ↔ HASHTAGS
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

// POST → SAVED
Post.hasMany(SavedPost, {
  foreignKey: 'post_id',
  as: 'saves',
  onDelete: 'CASCADE',
});
SavedPost.belongsTo(Post, { foreignKey: 'post_id', as: 'post' });

// USER → SAVED POSTS
User.hasMany(SavedPost, {
  foreignKey: 'user_id',
  as: 'savedPosts',
  onDelete: 'CASCADE',
});
SavedPost.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// POST → COMMENTS
Post.hasMany(Comment, {
  foreignKey: 'post_id',
  as: 'comments',
  onDelete: 'CASCADE',
});
Comment.belongsTo(Post, { foreignKey: 'post_id', as: 'post' });

// USER → COMMENTS
User.hasMany(Comment, {
  foreignKey: 'user_id',
  as: 'comments',
  onDelete: 'CASCADE',
});
Comment.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// COMMENT → REPLIES (self-referencing)
Comment.hasMany(Comment, {
  foreignKey: 'parent_comment_id',
  as: 'replies',
  onDelete: 'CASCADE',
});
Comment.belongsTo(Comment, {
  foreignKey: 'parent_comment_id',
  as: 'parent',
});

// COMMENT → COMMENT LIKES
Comment.hasMany(CommentLike, {
  foreignKey: 'comment_id',
  as: 'likes',
  onDelete: 'CASCADE',
});
CommentLike.belongsTo(Comment, {
  foreignKey: 'comment_id',
  as: 'comment',
});
User.hasMany(CommentLike, {
  foreignKey: 'user_id',
  as: 'commentLikes',
  onDelete: 'CASCADE',
});
CommentLike.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user',
});

// ─── FOLLOW ASSOCIATIONS ───────────────────────────────────

// A user has many FOLLOWERS (people following them)
User.hasMany(Follower, {
  foreignKey: 'following_id',  // "I am being followed"
  as: 'followers',
  onDelete: 'CASCADE',
});

// A user FOLLOWS many people
User.hasMany(Follower, {
  foreignKey: 'follower_id',   // "I am following"
  as: 'following',
  onDelete: 'CASCADE',
});

// Follower belongs to the person being followed
Follower.belongsTo(User, {
  foreignKey: 'following_id',
  as: 'followingUser',
});

// Follower belongs to the person who is following
Follower.belongsTo(User, {
  foreignKey: 'follower_id',
  as: 'followerUser',
});

// ─── BLOCK ASSOCIATIONS ────────────────────────────────────
User.hasMany(Block, {
  foreignKey: 'blocker_id',
  as: 'blockedUsers',
  onDelete: 'CASCADE',
});
Block.belongsTo(User, {
  foreignKey: 'blocker_id',
  as: 'blocker',
});
Block.belongsTo(User, {
  foreignKey: 'blocked_id',
  as: 'blockedUser',
});

// ─── SYNC DATABASE ─────────────────────────────────────────
const syncDatabase = async () => {
  try {
    await sequelize.sync({ alter: true });
    console.log('✅ Database tables synced!');
    console.log('   → users');
    console.log('   → posts');
    console.log('   → post_media');
    console.log('   → likes');
    console.log('   → hashtags');
    console.log('   → post_hashtags');
    console.log('   → saved_posts');
    console.log('   → comments');
    console.log('   → comment_likes');
    console.log('   → followers');  // ⭐ NEW
    console.log('   → blocks');     // ⭐ NEW
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
  Comment,
  CommentLike,
  Follower,
  Block,
};