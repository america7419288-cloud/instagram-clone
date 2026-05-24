const { Block, User, Follower } = require('../models');
const { Op } = require('sequelize');

const getBlockedAccounts = async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 30 } = req.query;

    const { count, rows: blocks } = await Block.findAndCountAll({
      where: { blocker_id: userId },
      include: [
        {
          model: User,
          as: 'blockedUser',
          attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified'],
        }
      ],
      order: [['createdAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: parseInt(limit),
    });

    const blockedAccountsList = blocks
      .filter(b => b.blockedUser)
      .map(b => {
        const u = b.blockedUser.toJSON();
        return {
          user: u,
          blockedAt: b.createdAt,
        };
      });

    return res.status(200).json({
      success: true,
      data: {
        blockedAccounts: blockedAccountsList,
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

const blockAccount = async (req, res) => {
  try {
    const { userId: targetId } = req.params;
    const userId = req.user.id;

    if (userId === targetId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot block yourself',
      });
    }

    const existing = await Block.findOne({
      where: { blocker_id: userId, blocked_id: targetId }
    });

    if (existing) {
      return res.status(400).json({
        success: false,
        message: 'Already blocked',
      });
    }

    await Block.create({
      blocker_id: userId,
      blocked_id: targetId,
    });

    // Remove any following/follower relationship
    await Follower.destroy({
      where: {
        [Op.or]: [
          { followerId: userId, followingId: targetId },
          { followerId: targetId, followingId: userId }
        ]
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Account blocked',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const unblockAccount = async (req, res) => {
  try {
    const { userId: targetId } = req.params;
    const userId = req.user.id;

    await Block.destroy({
      where: { blocker_id: userId, blocked_id: targetId }
    });

    return res.status(200).json({
      success: true,
      message: 'Account unblocked',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const isBlocked = async (req, res) => {
  try {
    const { userId: targetId } = req.params;
    const userId = req.user.id;

    const block = await Block.findOne({
      where: { blocker_id: userId, blocked_id: targetId }
    });

    return res.status(200).json({
      success: true,
      data: { isBlocked: !!block },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

module.exports = {
  getBlockedAccounts,
  blockAccount,
  unblockAccount,
  isBlocked,
};
