// server/src/models/index.js

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
const Conversation = require('./Conversation.model');
const ConversationParticipant = require('./ConversationParticipant.model');
const Message = require('./Message.model');
const Reel = require('./Reel.model');
const ReelLike = require('./ReelLike.model');
const SavedReel = require('./SavedReel.model');
const StoryPoll = require('./StoryPoll.model');
const StoryPollVote = require('./StoryPollVote.model');
const StoryQuestion = require('./StoryQuestion.model');
const StoryAnswer = require('./StoryAnswer.model');
const StoryReaction = require('./StoryReaction.model');
const StoryHighlight = require('./StoryHighlight.model');
const StoryHighlightItem = require('./StoryHighlightItem.model');
const PostTag = require('./PostTag.model');

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

// ─── Post → PostTag ───────────────────────────────────
Post.hasMany(PostTag, {
  foreignKey: 'postId',
  as: 'tags',
  onDelete: 'CASCADE',
});
PostTag.belongsTo(Post, { foreignKey: 'postId', as: 'post' });
PostTag.belongsTo(User, {
  foreignKey: 'userId',
  as: 'user',
});
User.hasMany(PostTag, {
  foreignKey: 'userId',
  as: 'taggedIn',
  onDelete: 'CASCADE',
});

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

// ─── User → Reel ──────────────────────────────────────
User.hasMany(Reel, {
  foreignKey: 'userId',
  as: 'reels',
  onDelete: 'CASCADE',
});
Reel.belongsTo(User, {
  foreignKey: 'userId',
  as: 'user',
});

// ─── Story → StoryPoll ────────────────────────────────
Story.hasOne(StoryPoll, { foreignKey: 'storyId', as: 'poll', onDelete: 'CASCADE' });
StoryPoll.belongsTo(Story, { foreignKey: 'storyId' });

// ─── StoryPoll → StoryPollVote ────────────────────────
StoryPoll.hasMany(StoryPollVote, { foreignKey: 'pollId', as: 'votes', onDelete: 'CASCADE' });
StoryPollVote.belongsTo(StoryPoll, { foreignKey: 'pollId', as: 'poll' });
StoryPollVote.belongsTo(User, { foreignKey: 'userId', as: 'user' });
StoryPollVote.belongsTo(Story, { foreignKey: 'storyId' });

// ─── Story → StoryQuestion ────────────────────────────
Story.hasOne(StoryQuestion, { foreignKey: 'storyId', as: 'question', onDelete: 'CASCADE' });
StoryQuestion.belongsTo(Story, { foreignKey: 'storyId' });

// ─── StoryQuestion → StoryAnswer ─────────────────────
StoryQuestion.hasMany(StoryAnswer, { foreignKey: 'questionId', as: 'answers', onDelete: 'CASCADE' });
StoryAnswer.belongsTo(StoryQuestion, { foreignKey: 'questionId', as: 'question' });
StoryAnswer.belongsTo(User, { foreignKey: 'userId', as: 'user' });
StoryAnswer.belongsTo(Story, { foreignKey: 'storyId' });

// ─── Story → StoryReaction ────────────────────────────
Story.hasMany(StoryReaction, { foreignKey: 'storyId', as: 'reactions', onDelete: 'CASCADE' });
StoryReaction.belongsTo(Story, { foreignKey: 'storyId' });
StoryReaction.belongsTo(User, { foreignKey: 'userId', as: 'user' });

// ─── User → StoryHighlight ────────────────────────────
User.hasMany(StoryHighlight, { foreignKey: 'userId', as: 'highlights', onDelete: 'CASCADE' });
StoryHighlight.belongsTo(User, { foreignKey: 'userId', as: 'user' });

// ─── StoryHighlight → StoryHighlightItem ─────────────
StoryHighlight.hasMany(StoryHighlightItem, {
  foreignKey: 'highlightId',
  as: 'items',
  onDelete: 'CASCADE',
});
StoryHighlightItem.belongsTo(StoryHighlight, {
  foreignKey: 'highlightId',
  as: 'highlight',
});
StoryHighlightItem.belongsTo(Story, { foreignKey: 'storyId' });

// ─── Reel → ReelLike ──────────────────────────────────
Reel.hasMany(ReelLike, {
  foreignKey: 'reelId',
  as: 'likes',
  onDelete: 'CASCADE',
});
ReelLike.belongsTo(Reel, { foreignKey: 'reelId' });
ReelLike.belongsTo(User, { foreignKey: 'userId', as: 'user' });
User.hasMany(ReelLike, {
  foreignKey: 'userId',
  onDelete: 'CASCADE',
});

// ─── Reel → SavedReel ─────────────────────────────────
Reel.hasMany(SavedReel, {
  foreignKey: 'reelId',
  as: 'saves',
  onDelete: 'CASCADE',
});
SavedReel.belongsTo(Reel, { foreignKey: 'reelId', as: 'reel' });
User.hasMany(SavedReel, {
  foreignKey: 'userId',
  as: 'savedReels',
  onDelete: 'CASCADE',
});
SavedReel.belongsTo(User, { foreignKey: 'userId', as: 'user' });

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

// MESSAGE → SHARED POST / REEL / STORY (polymorphic via shared_post_id)
Message.belongsTo(Post, {
  foreignKey: 'shared_post_id',
  as: 'sharedPost',
  constraints: false,
});
Message.belongsTo(Reel, {
  foreignKey: 'shared_post_id',
  as: 'sharedReel',
  constraints: false,
});
Message.belongsTo(Story, {
  foreignKey: 'shared_post_id',
  as: 'sharedStory',
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

    // Step 1: Sync table structure
    // In development: alter:true so Sequelize creates/modifies columns freely.
    // In production: alter:false — we manage schema changes with safe SQL below.
    const shouldAlter = !isProduction;
    await sequelize.sync({ alter: shouldAlter });
    console.log(
      `✅ Database synced (alter: ${shouldAlter}) in ${isProduction ? 'production' : 'development'} mode`
    );

    // Safe ALTER TYPE queries for message_type enum (Postgres-specific, non-blocking)
    try {
      await sequelize.query("ALTER TYPE enum_messages_message_type ADD VALUE IF NOT EXISTS 'post'");
      await sequelize.query("ALTER TYPE enum_messages_message_type ADD VALUE IF NOT EXISTS 'reel'");
      await sequelize.query("ALTER TYPE enum_messages_message_type ADD VALUE IF NOT EXISTS 'story'");
      await sequelize.query("ALTER TYPE enum_messages_message_type ADD VALUE IF NOT EXISTS 'profile'");
      await sequelize.query("ALTER TYPE enum_messages_message_type ADD VALUE IF NOT EXISTS 'like'");
      await sequelize.query("ALTER TYPE enum_messages_message_type ADD VALUE IF NOT EXISTS 'gif'");
      console.log('✅ Message type enum values ensured in database');
    } catch (enumError) {
      console.warn('⚠️ Warning: Failed to alter message_type enum:', enumError.message);
    }

    // Step 2: Safe additive migrations — idempotent, never drops data.
    // ADD COLUMN IF NOT EXISTS and CREATE TABLE IF NOT EXISTS are safe to run
    // on every server startup against both dev and production databases.
    await sequelize.query(`
      ALTER TABLE conversations
        ADD COLUMN IF NOT EXISTS disappearing_duration INTEGER DEFAULT NULL;

      ALTER TABLE messages
        ADD COLUMN IF NOT EXISTS is_edited  BOOLEAN   NOT NULL DEFAULT FALSE;
      ALTER TABLE messages
        ADD COLUMN IF NOT EXISTS edited_at  TIMESTAMP WITH TIME ZONE DEFAULT NULL;
      ALTER TABLE messages
        ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
      ALTER TABLE messages
        ADD COLUMN IF NOT EXISTS reactions  JSONB NOT NULL DEFAULT '{}';

      CREATE TABLE IF NOT EXISTS saved_reels (
        id          UUID                     PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id     UUID                     NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
        reel_id     UUID                     NOT NULL REFERENCES reels(id)  ON DELETE CASCADE,
        created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        CONSTRAINT  unique_user_reel_save UNIQUE (user_id, reel_id)
      );
      CREATE INDEX IF NOT EXISTS idx_saved_reels_user_id ON saved_reels (user_id);
      CREATE INDEX IF NOT EXISTS idx_saved_reels_reel_id ON saved_reels (reel_id);
    `);

    console.log('✅ Database tables synced!');
    console.log('   → users, posts, post_media');
    console.log('   → likes, hashtags, post_hashtags');
    console.log('   → saved_posts, saved_reels, comments, comment_likes');
    console.log('   → followers, blocks');
    console.log('   → stories, story_views');
    console.log('   → notifications');
    console.log('   → conversations (+ disappearing_duration)');
    console.log('   → conversation_participants');
    console.log('   → messages (+ is_edited, edited_at, expires_at, reactions)');
    console.log('   → post_tags');
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
  Reel,
  ReelLike,
  SavedReel,
  StoryPoll,
  StoryPollVote,
  StoryQuestion,
  StoryAnswer,
  StoryReaction,
  StoryHighlight,
  StoryHighlightItem,
  PostTag,
};
