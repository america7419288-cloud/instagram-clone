const { CloseFriend, User } = require('../models');
const { Op } = require('sequelize');

const getCloseFriends = async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 30, search } = req.query;

    const includeUserOptions = {
      model: User,
      as: 'friend',
      attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified'],
    };

    if (search) {
      includeUserOptions.where = {
        username: {
          [Op.iLike]: `%${search}%`,
        },
      };
    }

    const { count, rows: closeFriends } = await CloseFriend.findAndCountAll({
      where: { userId },
      include: [includeUserOptions],
      order: [['addedAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: parseInt(limit),
    });

    const friendsList = closeFriends
      .filter(f => f.friend)
      .map(f => {
        const u = f.friend.toJSON();
        return {
          id: u.id,
          username: u.username,
          fullName: u.fullName,
          profile_pic_url: u.profile_pic_url,
          is_verified: u.is_verified,
          addedAt: f.addedAt,
          isCloseFriend: true,
        };
      });

    return res.status(200).json({
      success: true,
      data: {
        closeFriends: friendsList,
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

const addCloseFriend = async (req, res) => {
  try {
    const { userId: friendId } = req.params;
    const userId = req.user.id;

    if (userId === friendId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot add yourself',
      });
    }

    await CloseFriend.findOrCreate({
      where: { userId, friendId },
      defaults: { addedAt: new Date() }
    });

    return res.status(201).json({
      success: true,
      message: 'Added to close friends',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const removeCloseFriend = async (req, res) => {
  try {
    const { userId: friendId } = req.params;
    const userId = req.user.id;

    await CloseFriend.destroy({
      where: { userId, friendId }
    });

    return res.status(200).json({
      success: true,
      message: 'Removed from close friends',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const isCloseFriend = async (req, res) => {
  try {
    const { userId: friendId } = req.params;
    const userId = req.user.id;

    const friend = await CloseFriend.findOne({
      where: { userId, friendId }
    });

    return res.status(200).json({
      success: true,
      data: { isCloseFriend: !!friend },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

module.exports = {
  getCloseFriends,
  addCloseFriend,
  removeCloseFriend,
  isCloseFriend,
};
