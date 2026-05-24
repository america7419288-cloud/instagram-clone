const { MutedAccount, User } = require('../models');

const getMutedAccounts = async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 30 } = req.query;

    const { count, rows: muted } = await MutedAccount.findAndCountAll({
      where: { userId },
      include: [
        {
          model: User,
          as: 'mutedUser',
          attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified'],
        }
      ],
      order: [['mutedAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: parseInt(limit),
    });

    const mutedAccountsList = muted
      .filter(m => m.mutedUser)
      .map(m => {
        const u = m.mutedUser.toJSON();
        return {
          user: u,
          mutePosts: m.mutePosts,
          muteStories: m.muteStories,
          mutedAt: m.mutedAt,
        };
      });

    return res.status(200).json({
      success: true,
      data: {
        mutedAccounts: mutedAccountsList,
        total: count,
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const muteAccount = async (req, res) => {
  try {
    const { userId: mutedUserId } = req.params;
    const { mutePosts = true, muteStories = false } = req.body;
    const userId = req.user.id;

    if (userId === mutedUserId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot mute yourself',
      });
    }

    const [muted, created] = await MutedAccount.findOrCreate({
      where: { userId, mutedUserId },
      defaults: { mutePosts, muteStories, mutedAt: new Date() }
    });

    if (!created) {
      await muted.update({ mutePosts, muteStories });
    }

    return res.status(201).json({
      success: true,
      message: 'Account muted',
      data: { muted },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const updateMuteSettings = async (req, res) => {
  try {
    const { userId: mutedUserId } = req.params;
    const { mutePosts, muteStories } = req.body;
    const userId = req.user.id;

    const muted = await MutedAccount.findOne({
      where: { userId, mutedUserId }
    });

    if (!muted) {
      return res.status(404).json({
        success: false,
        message: 'Account not muted',
      });
    }

    await muted.update({
      ...(mutePosts !== undefined && { mutePosts }),
      ...(muteStories !== undefined && { muteStories }),
    });

    return res.status(200).json({
      success: true,
      message: 'Mute settings updated',
      data: { muted },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const unmuteAccount = async (req, res) => {
  try {
    const { userId: mutedUserId } = req.params;
    const userId = req.user.id;

    await MutedAccount.destroy({
      where: { userId, mutedUserId }
    });

    return res.status(200).json({
      success: true,
      message: 'Account unmuted',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

module.exports = {
  getMutedAccounts,
  muteAccount,
  updateMuteSettings,
  unmuteAccount,
};
