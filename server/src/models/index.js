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
const Follower = require('./Follower.model');
const Block = require('./Block.model');
const Story = require('./Story.model');
const StoryView = require('./StoryView.model');
const Notification = require('./Notification.model'); // ⭐ NEW

// ─── ASSOCIATIONS ──────────────────────────────────────────

// USER → POSTS
User.hasMany(Post, {
  foreignKey: 'user_id',
  as: 'posts',
  onDelete: 'CASCADE',
});
Post.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// POST → MEDIA
Post.hasMany(PostMedia, {
  foreignKey: 'post_id',
  as: 'media',
  onDelete: 'CASCADE',
});
PostMedia.belongsTo(Post, { foreignKey: 'post_id', as: 'post' });

// POST → LIKES
Post.hasMany(Like, {
  foreignKey: 'post_id',
  as: 'likes',
  onDelete: 'CASCADE',
});
Like.belongsTo(Post, { foreignKey: 'post_id', as: 'post' });
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

// SAVED POSTS
Post.hasMany(SavedPost, {
  foreignKey: 'post_id',
  as: 'saves',
  onDelete: 'CASCADE',
});
SavedPost.belongsTo(Post, { foreignKey: 'post_id', as: 'post' });
User.hasMany(SavedPost, {
  foreignKey: 'user_id',
  as: 'savedPosts',
  onDelete: 'CASCADE',
});
SavedPost.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// COMMENTS
Post.hasMany(Comment, {
  foreignKey: 'post_id',
  as: 'comments',
  onDelete: 'CASCADE',
});
Comment.belongsTo(Post, { foreignKey: 'post_id', as: 'post' });
User.hasMany(Comment, {
  foreignKey: 'user_id',
  as: 'comments',
  onDelete: 'CASCADE',
});
Comment.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// COMMENT REPLIES (self-ref)
Comment.hasMany(Comment, {
  foreignKey: 'parent_comment_id',
  as: 'replies',
  onDelete: 'CASCADE',
});
Comment.belongsTo(Comment, {
  foreignKey: 'parent_comment_id',
  as: 'parent',
});

// COMMENT LIKES
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

// FOLLOWERS
User.hasMany(Follower, {
  foreignKey: 'following_id',
  as: 'followers',
  onDelete: 'CASCADE',
});
User.hasMany(Follower, {
  foreignKey: 'follower_id',
  as: 'following',
  onDelete: 'CASCADE',
});
Follower.belongsTo(User, {
  foreignKey: 'following_id',
  as: 'followingUser',
});
Follower.belongsTo(User, {
  foreignKey: 'follower_id',
  as: 'followerUser',
});

// BLOCKS
User.hasMany(Block, {
  foreignKey: 'blocker_id',
  as: 'blockedUsers',
  onDelete: 'CASCADE',
});
Block.belongsTo(User, { foreignKey: 'blocker_id', as: 'blocker' });
Block.belongsTo(User, {
  foreignKey: 'blocked_id',
  as: 'blockedUser',
});

// STORIES
User.hasMany(Story, {
  foreignKey: 'user_id',
  as: 'stories',
  onDelete: 'CASCADE',
});
Story.belongsTo(User, { foreignKey: 'user_id', as: 'user' });
Story.hasMany(StoryView, {
  foreignKey: 'story_id',
  as: 'views',
  onDelete: 'CASCADE',
});
StoryView.belongsTo(Story, {
  foreignKey: 'story_id',
  as: 'story',
});
User.hasMany(StoryView, {
  foreignKey: 'viewer_id',
  as: 'storyViews',
  onDelete: 'CASCADE',
});
StoryView.belongsTo(User, {
  foreignKey: 'viewer_id',
  as: 'viewer',
});

// ─── NOTIFICATION ASSOCIATIONS ─────────────────────────────

// User receives many notifications
User.hasMany(Notification, {
  foreignKey: 'recipient_id',
  as: 'receivedNotifications',
  onDelete: 'CASCADE',
});
Notification.belongsTo(User, {
  foreignKey: 'recipient_id',
  as: 'recipient',
});

// User sends/triggers many notifications
User.hasMany(Notification, {
  foreignKey: 'sender_id',
  as: 'sentNotifications',
  onDelete: 'CASCADE',
});
Notification.belongsTo(User, {
  foreignKey: 'sender_id',
  as: 'sender',
});

// Notification references a post
Notification.belongsTo(Post, {
  foreignKey: 'reference_post_id',
  as: 'referencePost',
  constraints: false, // Allow null
});

// Notification references a comment
Notification.belongsTo(Comment, {
  foreignKey: 'reference_comment_id',
  as: 'referenceComment',
  constraints: false,
});

// Notification references a story
Notification.belongsTo(Story, {
  foreignKey: 'reference_story_id',
  as: 'referenceStory',
  constraints: false,
});

// ─── SYNC DATABASE ─────────────────────────────────────────
const syncDatabase = async () => {
  try {
    await sequelize.sync({ alter: true });
    console.log('✅ Database tables synced!');
    console.log('   → users, posts, post_media');
    console.log('   → likes, hashtags, post_hashtags');
    console.log('   → saved_posts, comments, comment_likes');
    console.log('   → followers, blocks');
    console.log('   → stories, story_views');
    console.log('   → notifications'); // ⭐ NEW
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
  Story,
  StoryView,
  Notification,
};