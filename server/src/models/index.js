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
const Note = require('./Note.model');
const Report = require('./Report.model');

// ─── ALL ASSOCIATIONS ──────────────────────────────────────

// USER → POSTS
User.hasMany(Post, {
  foreignKey: 'user_id',
  as: 'posts',
  onDelete: 'CASCADE',
});
Post.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// USER → NOTES
User.hasMany(Note, {
  foreignKey: 'user_id',
  as: 'notes',
  onDelete: 'CASCADE',
});
Note.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// ─── Post → PostMedia ─────────────────────────────────
Post.hasMany(PostMedia, {
  foreignKey: 'postId',
  as: 'mediaFiles',
  onDelete: 'CASCADE',
});
Post.hasMany(PostMedia, {
  foreignKey: 'postId',
  as: 'media',
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
  foreignKey: 'post_id',
  as: 'post',
  constraints: false,
});
Notification.belongsTo(Comment, {
  foreignKey: 'comment_id',
  as: 'comment',
  constraints: false,
});
Notification.belongsTo(Story, {
  foreignKey: 'story_id',
  as: 'story',
  constraints: false,
});
Notification.belongsTo(Reel, {
  foreignKey: 'reel_id',
  as: 'reel',
  constraints: false,
});
// Legacy aliases (keep for compatibility)
Notification.belongsTo(Post, {
  foreignKey: 'post_id',
  as: 'referencePost',
  constraints: false,
});
Notification.belongsTo(Comment, {
  foreignKey: 'comment_id',
  as: 'referenceComment',
  constraints: false,
});
Notification.belongsTo(Story, {
  foreignKey: 'story_id',
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

// REPORTS ASSOCIATIONS
Report.belongsTo(User, { foreignKey: 'reported_by', as: 'reporter' });
User.hasMany(Report, { foreignKey: 'reported_by', as: 'reportsSubmitted' });

Report.belongsTo(User, { foreignKey: 'reported_user_id', as: 'reportedUser' });
User.hasMany(Report, { foreignKey: 'reported_user_id', as: 'reportsAgainst' });

Report.belongsTo(Message, { foreignKey: 'reported_message_id', as: 'reportedMessage' });
Message.hasMany(Report, { foreignKey: 'reported_message_id', as: 'reports' });

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

      ALTER TABLE conversation_participants
        ADD COLUMN IF NOT EXISTS is_accepted BOOLEAN NOT NULL DEFAULT TRUE;

      ALTER TABLE messages
        DROP CONSTRAINT IF EXISTS messages_shared_post_id_fkey;

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

      CREATE TABLE IF NOT EXISTS notes (
        id          UUID                     PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id     UUID                     NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        text        VARCHAR(60)              NOT NULL,
        audience    VARCHAR(50)              NOT NULL DEFAULT 'followers',
        expires_at  TIMESTAMP WITH TIME ZONE NOT NULL,
        created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes (user_id);
      CREATE INDEX IF NOT EXISTS idx_notes_expires_at ON notes (expires_at);

      -- Additive migrations for conversation participants mute & unread states
      ALTER TABLE conversation_participants
        ADD COLUMN IF NOT EXISTS muted_until TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS is_unread   BOOLEAN NOT NULL DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS deleted_at   TIMESTAMP WITH TIME ZONE DEFAULT NULL;

      -- Additive migrations for Notes Music & GIFs
      ALTER TABLE notes
        ADD COLUMN IF NOT EXISTS note_type         VARCHAR(50) DEFAULT 'text',
        ADD COLUMN IF NOT EXISTS music_track_id    VARCHAR(255),
        ADD COLUMN IF NOT EXISTS music_track_name  VARCHAR(255),
        ADD COLUMN IF NOT EXISTS music_artist_name VARCHAR(255),
        ADD COLUMN IF NOT EXISTS music_album_art   VARCHAR(500),
        ADD COLUMN IF NOT EXISTS music_preview_url VARCHAR(500),
        ADD COLUMN IF NOT EXISTS music_duration    INTEGER,
        ADD COLUMN IF NOT EXISTS music_platform    VARCHAR(50) DEFAULT 'spotify',
        ADD COLUMN IF NOT EXISTS gif_id            VARCHAR(255),
        ADD COLUMN IF NOT EXISTS gif_url            VARCHAR(500),
        ADD COLUMN IF NOT EXISTS gif_preview_url    VARCHAR(500),
        ADD COLUMN IF NOT EXISTS gif_title          VARCHAR(255),
        ADD COLUMN IF NOT EXISTS gif_width          INTEGER,
        ADD COLUMN IF NOT EXISTS gif_height         INTEGER,
        ADD COLUMN IF NOT EXISTS gif_source         VARCHAR(50) DEFAULT 'giphy';

      -- Create Reports table
      CREATE TABLE IF NOT EXISTS reports (
        id                  UUID                     PRIMARY KEY DEFAULT gen_random_uuid(),
        reported_by         UUID                     NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        reported_user_id    UUID                     REFERENCES users(id) ON DELETE CASCADE,
        reported_message_id UUID                     REFERENCES messages(id) ON DELETE CASCADE,
        report_type         VARCHAR(100)             NOT NULL,
        description         TEXT,
        status              VARCHAR(50)              NOT NULL DEFAULT 'pending',
        created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_reports_reported_by ON reports (reported_by);
      CREATE INDEX IF NOT EXISTS idx_reports_reported_user_id ON reports (reported_user_id);

      -- Additive migrations for Notifications table
      ALTER TABLE notifications
        ADD COLUMN IF NOT EXISTS post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
        ADD COLUMN IF NOT EXISTS comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
        ADD COLUMN IF NOT EXISTS story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
        ADD COLUMN IF NOT EXISTS reel_id UUID REFERENCES reels(id) ON DELETE CASCADE;
    `);

    // Safe data migration for Notifications
    try {
      await sequelize.query(`
        UPDATE notifications SET post_id = reference_post_id WHERE post_id IS NULL AND reference_post_id IS NOT NULL;
        UPDATE notifications SET comment_id = reference_comment_id WHERE comment_id IS NULL AND reference_comment_id IS NOT NULL;
        UPDATE notifications SET story_id = reference_story_id WHERE story_id IS NULL AND reference_story_id IS NOT NULL;
      `);
      console.log('✅ Legacy notification columns data migrated successfully');
    } catch (migError) {
      // Safe to ignore if reference columns don't exist
      console.log('ℹ️ Notification legacy columns not found or already migrated');
    }

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
  StoryHighlightItem: StoryHighlightItem,
  PostTag: PostTag,
  Note: Note,
  Report: Report,
};
