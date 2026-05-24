const { UserSettings, User, Follower } = require('../models');

// GET ALL SETTINGS
const getAllSettings = async (req, res) => {
  try {
    let settings = await UserSettings.findOne({
      where: { userId: req.user.id }
    });

    // Create default settings if not exists
    if (!settings) {
      settings = await UserSettings.create({
        userId: req.user.id,
      });
    }

    return res.status(200).json({
      success: true,
      data: { settings },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// UPDATE PRIVACY
const updatePrivacy = async (req, res) => {
  try {
    const {
      isPrivateAccount,
      showActivityStatus,
      allowStoryReplies,
      allowTagging,
      allowMentions,
      showSuggestedAccounts,
    } = req.body;

    let settings = await UserSettings.findOne({
      where: { userId: req.user.id }
    });

    if (!settings) {
      settings = await UserSettings.create({ userId: req.user.id });
    }

    const updatedPrivacy = {
      ...settings.privacy,
      ...(isPrivateAccount !== undefined && { isPrivateAccount }),
      ...(showActivityStatus !== undefined && { showActivityStatus }),
      ...(allowStoryReplies !== undefined && { allowStoryReplies }),
      ...(allowTagging !== undefined && { allowTagging }),
      ...(allowMentions !== undefined && { allowMentions }),
      ...(showSuggestedAccounts !== undefined && { showSuggestedAccounts }),
    };

    await settings.update({ privacy: updatedPrivacy });

    // Update user's is_private field
    if (isPrivateAccount !== undefined) {
      await User.update(
        { is_private: isPrivateAccount },
        { where: { id: req.user.id } }
      );

      // If switching to public, auto-approve all follow requests
      if (!isPrivateAccount) {
        await Follower.update(
          { status: 'accepted' },
          { where: { followingId: req.user.id, status: 'pending' } }
        );
      }
    }

    return res.status(200).json({
      success: true,
      message: 'Privacy settings updated',
      data: { settings },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// UPDATE COMMENTS
const updateComments = async (req, res) => {
  try {
    const {
      allowComments,
      filterOffensiveComments,
      manualFilter,
      filteredWords,
      allowCommentLikes,
      pinComments,
    } = req.body;

    let settings = await UserSettings.findOne({
      where: { userId: req.user.id }
    });

    if (!settings) {
      settings = await UserSettings.create({ userId: req.user.id });
    }

    const updatedComments = {
      ...settings.comments,
      ...(allowComments !== undefined && { allowComments }),
      ...(filterOffensiveComments !== undefined && { filterOffensiveComments }),
      ...(manualFilter !== undefined && { manualFilter }),
      ...(filteredWords !== undefined && { filteredWords }),
      ...(allowCommentLikes !== undefined && { allowCommentLikes }),
      ...(pinComments !== undefined && { pinComments }),
    };

    await settings.update({ comments: updatedComments });

    return res.status(200).json({
      success: true,
      message: 'Comment settings updated',
      data: { settings },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// UPDATE LIKES & SHARES
const updateLikesShares = async (req, res) => {
  try {
    const {
      hideLikeCount,
      hideOthersLikeCount,
      allowSharing,
      allowStorySharing,
      allowReelSharing,
    } = req.body;

    let settings = await UserSettings.findOne({
      where: { userId: req.user.id }
    });

    if (!settings) {
      settings = await UserSettings.create({ userId: req.user.id });
    }

    const updatedLikesShares = {
      ...settings.likesAndShares,
      ...(hideLikeCount !== undefined && { hideLikeCount }),
      ...(hideOthersLikeCount !== undefined && { hideOthersLikeCount }),
      ...(allowSharing !== undefined && { allowSharing }),
      ...(allowStorySharing !== undefined && { allowStorySharing }),
      ...(allowReelSharing !== undefined && { allowReelSharing }),
    };

    await settings.update({ likesAndShares: updatedLikesShares });

    return res.status(200).json({
      success: true,
      message: 'Likes & shares settings updated',
      data: { settings },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// UPDATE NOTIFICATIONS
const updateNotifications = async (req, res) => {
  try {
    let settings = await UserSettings.findOne({
      where: { userId: req.user.id }
    });

    if (!settings) {
      settings = await UserSettings.create({ userId: req.user.id });
    }

    const fields = [
      'pushEnabled', 'likes', 'comments', 'commentLikes',
      'newFollowers', 'followRequests', 'acceptedFollowRequests',
      'mentions', 'tags', 'directMessages', 'groupRequests',
      'liveVideos', 'reels', 'stories', 'emailNotifications',
      'smsNotifications', 'pauseAll', 'pauseUntil',
    ];

    const updatedNotifications = { ...settings.notifications };
    fields.forEach(field => {
      if (req.body[field] !== undefined) {
        updatedNotifications[field] = req.body[field];
      }
    });

    await settings.update({ notifications: updatedNotifications });

    return res.status(200).json({
      success: true,
      message: 'Notification settings updated',
      data: { settings },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// UPDATE TIMESTAMP
const updateTimestamp = async (req, res) => {
  try {
    const {
      showTimestamp,
      format,
      use24HourFormat,
      showSeenTimestamp,
    } = req.body;

    let settings = await UserSettings.findOne({
      where: { userId: req.user.id }
    });

    if (!settings) {
      settings = await UserSettings.create({ userId: req.user.id });
    }

    const updatedTimestamp = {
      ...settings.timestamp,
      ...(showTimestamp !== undefined && { showTimestamp }),
      ...(format !== undefined && { format }),
      ...(use24HourFormat !== undefined && { use24HourFormat }),
      ...(showSeenTimestamp !== undefined && { showSeenTimestamp }),
    };

    await settings.update({ timestamp: updatedTimestamp });

    return res.status(200).json({
      success: true,
      message: 'Timestamp settings updated',
      data: { settings },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// UPDATE ARCHIVE SETTINGS
const updateArchiveSettings = async (req, res) => {
  try {
    const {
      autoArchiveStories,
      autoArchivePosts,
      showArchiveInProfile,
    } = req.body;

    let settings = await UserSettings.findOne({
      where: { userId: req.user.id }
    });

    if (!settings) {
      settings = await UserSettings.create({ userId: req.user.id });
    }

    const updatedArchive = {
      ...settings.archive,
      ...(autoArchiveStories !== undefined && { autoArchiveStories }),
      ...(autoArchivePosts !== undefined && { autoArchivePosts }),
      ...(showArchiveInProfile !== undefined && { showArchiveInProfile }),
    };

    await settings.update({ archive: updatedArchive });

    return res.status(200).json({
      success: true,
      message: 'Archive settings updated',
      data: { settings },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// UPDATE SAVED SETTINGS
const updateSavedSettings = async (req, res) => {
  try {
    const { defaultCollection, showSavedCount } = req.body;

    let settings = await UserSettings.findOne({
      where: { userId: req.user.id }
    });

    if (!settings) {
      settings = await UserSettings.create({ userId: req.user.id });
    }

    const updatedSaved = {
      ...settings.saved,
      ...(defaultCollection !== undefined && { defaultCollection }),
      ...(showSavedCount !== undefined && { showSavedCount }),
    };

    await settings.update({ saved: updatedSaved });

    return res.status(200).json({
      success: true,
      message: 'Saved settings updated',
      data: { settings },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

module.exports = {
  getAllSettings,
  updatePrivacy,
  updateComments,
  updateLikesShares,
  updateNotifications,
  updateTimestamp,
  updateArchiveSettings,
  updateSavedSettings,
};
