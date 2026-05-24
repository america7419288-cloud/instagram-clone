const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const UserSettings = sequelize.define(
  'UserSettings',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      unique: true,
      field: 'user_id',
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },
    privacy: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {
        isPrivateAccount: false,
        showActivityStatus: true,
        allowStoryReplies: 'everyone',
        allowTagging: 'everyone',
        allowMentions: 'everyone',
        showSuggestedAccounts: true,
      },
    },
    comments: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {
        allowComments: 'everyone',
        filterOffensiveComments: true,
        manualFilter: false,
        filteredWords: [],
        allowCommentLikes: true,
        pinComments: true,
      },
    },
    likesAndShares: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {
        hideLikeCount: false,
        hideOthersLikeCount: false,
        allowSharing: 'everyone',
        allowStorySharing: true,
        allowReelSharing: true,
      },
      field: 'likes_and_shares',
    },
    notifications: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {
        pushEnabled: true,
        likes: 'everyone',
        comments: 'everyone',
        commentLikes: true,
        newFollowers: true,
        followRequests: true,
        acceptedFollowRequests: true,
        mentions: 'everyone',
        tags: true,
        directMessages: true,
        groupRequests: true,
        liveVideos: true,
        reels: true,
        stories: true,
        emailNotifications: true,
        smsNotifications: false,
        pauseAll: false,
        pauseUntil: null,
      },
    },
    timestamp: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {
        showTimestamp: true,
        format: 'relative',
        use24HourFormat: false,
        showSeenTimestamp: true,
      },
    },
    archive: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {
        autoArchiveStories: true,
        autoArchivePosts: false,
        showArchiveInProfile: false,
      },
    },
    saved: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {
        defaultCollection: 'All Posts',
        showSavedCount: false,
      },
    },
  },
  {
    tableName: 'user_settings',
    timestamps: true,
    underscored: true,
  }
);

module.exports = UserSettings;
