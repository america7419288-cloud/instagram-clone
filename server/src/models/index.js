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
const Notification = require('./Notification.model');
const Conversation = require('./Conversation.model');              // ⭐ NEW
const ConversationParticipant = require('./ConversationParticipant.model'); // ⭐ NEW
const Message = require('./Message.model');                        // ⭐ NEW

// ─── ALL ASSOCIATIONS ──────────────────────────────────────

// USER → POSTS
User.hasMany(Post, {
  foreignKey: 'user_id',
  as: 'posts',
  onDelete: 'CASCADE',
});
Post.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// ─── Post → PostMedia ─────────────────────────────────
Post.hasMany(PostMedia, {
  foreignKey: 'postId',
  as: 'mediaFiles',
  onDelete: 'CASCADE',
});
PostMedia.belongsTo(Post, {
  foreignKey: 'postId',
  as: 'post',
});

// ─── Post → Like ──────────────────────────────────────
Post.hasMany(Like, {
  foreignKey: 'postId',
  as: 'likes',
  onDelete: 'CASCADE',
});
Like.belongsTo(Post, { foreignKey: 'postId' });
User.hasMany(Like, {
  foreignKey: 'userId',
  as: 'likes',
  onDelete: 'CASCADE',
});
Like.belongsTo(User, { foreignKey: 'userId', as: 'user' });

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

// ─── Post → SavedPost ─────────────────────────────────
Post.hasMany(SavedPost, {
  foreignKey: 'postId',
  as: 'saves',
  onDelete: 'CASCADE',
});
SavedPost.belongsTo(Post, { foreignKey: 'postId', as: 'post' });
User.hasMany(SavedPost, {
  foreignKey: 'userId',
  as: 'savedPosts',
  onDelete: 'CASCADE',
});
SavedPost.belongsTo(User, { foreignKey: 'userId', as: 'user' });

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

// NOTIFICATIONS
User.hasMany(Notification, {
  foreignKey: 'recipient_id',
  as: 'receivedNotifications',
  onDelete: 'CASCADE',
});
Notification.belongsTo(User, {
  foreignKey: 'recipient_id',
  as: 'recipient',
});
User.hasMany(Notification, {
  foreignKey: 'sender_id',
  as: 'sentNotifications',
  onDelete: 'CASCADE',
});
Notification.belongsTo(User, {
  foreignKey: 'sender_id',
  as: 'sender',
});
Notification.belongsTo(Post, {
  foreignKey: 'reference_post_id',
  as: 'referencePost',
  constraints: false,
});
Notification.belongsTo(Comment, {
  foreignKey: 'reference_comment_id',
  as: 'referenceComment',
  constraints: false,
});
Notification.belongsTo(Story, {
  foreignKey: 'reference_story_id',
  as: 'referenceStory',
  constraints: false,
});

// ─── CONVERSATION ASSOCIATIONS ─────────────────────────────

// CONVERSATION → PARTICIPANTS (many-to-many through junction)
Conversation.belongsToMany(User, {
  through: ConversationParticipant,
  foreignKey: 'conversation_id',
  otherKey: 'user_id',
  as: 'participants',
});
User.belongsToMany(Conversation, {
  through: ConversationParticipant,
  foreignKey: 'user_id',
  otherKey: 'conversation_id',
  as: 'conversations',
});

// Direct access to participant records
Conversation.hasMany(ConversationParticipant, {
  foreignKey: 'conversation_id',
  as: 'participantRecords',
  onDelete: 'CASCADE',
});
ConversationParticipant.belongsTo(Conversation, {
  foreignKey: 'conversation_id',
  as: 'conversation',
});
ConversationParticipant.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user',
});

// CONVERSATION → MESSAGES
Conversation.hasMany(Message, {
  foreignKey: 'conversation_id',
  as: 'messages',
  onDelete: 'CASCADE',
});
Message.belongsTo(Conversation, {
  foreignKey: 'conversation_id',
  as: 'conversation',
});

// MESSAGE → SENDER
User.hasMany(Message, {
  foreignKey: 'sender_id',
  as: 'sentMessages',
  onDelete: 'CASCADE',
});
Message.belongsTo(User, {
  foreignKey: 'sender_id',
  as: 'sender',
});

// MESSAGE REPLY TO MESSAGE (self-ref)
Message.belongsTo(Message, {
  foreignKey: 'reply_to_message_id',
  as: 'repliedTo',
  constraints: false,
});

// MESSAGE → SHARED POST
Message.belongsTo(Post, {
  foreignKey: 'shared_post_id',
  as: 'sharedPost',
  constraints: false,
});

// CONVERSATION → CREATOR
Conversation.belongsTo(User, {
  foreignKey: 'created_by',
  as: 'creator',
  constraints: false,
});

// ─── SYNC DATABASE ─────────────────────────────────────────
const syncDatabase = async () => {
  try {
    const isProduction = process.env.NODE_ENV === 'production';

    if (isProduction) {
      // Production: only sync if table doesn't exist
      // Never alter existing tables automatically
      await sequelize.sync({ force: false, alter: false });
      console.log('✅ Database synced (production mode)');
    } else {
      // Development: auto-alter tables to add new columns
      // This adds thumbnailUrl, mediaType, duration to post_media
      await sequelize.sync({ alter: true });
      console.log('✅ Database synced (development mode - alter: true)');
    }
    
    console.log('✅ Database tables synced!');
    console.log('   → users, posts, post_media');
    console.log('   → likes, hashtags, post_hashtags');
    console.log('   → saved_posts, comments, comment_likes');
    console.log('   → followers, blocks');
    console.log('   → stories, story_views');
    console.log('   → notifications');
    console.log('   → conversations');              // ⭐ NEW
    console.log('   → conversation_participants');  // ⭐ NEW
    console.log('   → messages');                   // ⭐ NEW
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
  Conversation,
  ConversationParticipant,
  Message,
};