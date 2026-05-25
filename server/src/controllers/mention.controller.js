// server/src/controllers/mention.controller.js

const { User, ConversationParticipant, CommunityMember, Follower, Notification } = require('../models');
const { Op } = require('sequelize');
const { successResponse, errorResponse } = require('../utils/response.utils');

// ── GET SUGGESTED USERS ──────────────────────────────────────
const _getSuggestedMentions = async (req, res) => {
  try {
    const { context = 'general', contextId, limit = 8 } = req.query;
    const userId = req.user.id;
    let users = [];

    if (context === 'group' && contextId) {
      const participants = await ConversationParticipant.findAll({
        where: {
          conversation_id: contextId,
          left_at: null,
          user_id: { [Op.ne]: userId }
        },
        include: [{
          model: User,
          as: 'user',
          where: { is_active: true },
          attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified']
        }],
        limit: parseInt(limit)
      });
      users = participants.map(p => p.user).filter(Boolean);
    } else if (context === 'community' && contextId) {
      const members = await CommunityMember.findAll({
        where: {
          community_id: contextId,
          is_banned: false,
          user_id: { [Op.ne]: userId }
        },
        include: [{
          model: User,
          as: 'user',
          where: { is_active: true },
          attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified']
        }],
        limit: parseInt(limit)
      });
      users = members.map(m => m.user).filter(Boolean);
    } else {
      // General: get following list
      const following = await Follower.findAll({
        where: { followerId: userId, status: 'accepted' },
        attributes: ['followingId']
      });
      const followingIds = following.map(f => f.followingId);

      users = await User.findAll({
        where: {
          id: { [Op.in]: followingIds, [Op.ne]: userId },
          is_active: true
        },
        attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified'],
        limit: parseInt(limit)
      });
    }

    const mappedUsers = users.map(user => ({
      _id: user.id,
      id: user.id,
      username: user.username,
      fullName: user.fullName,
      profile_pic_url: user.profile_pic_url,
      avatarUrl: user.profile_pic_url,
      is_verified: user.is_verified,
      isVerified: user.is_verified
    }));

    return res.status(200).json({
      success: true,
      data: { users: mappedUsers, isSuggested: true }
    });
  } catch (error) {
    console.error('❌ _getSuggestedMentions error:', error);
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// ── SEARCH MENTIONS ──────────────────────────────────────────
const searchMentions = async (req, res) => {
  try {
    const { q = '', context = 'general', contextId, limit = 10 } = req.query;
    const userId = req.user.id;

    if (q.trim().length === 0) {
      return _getSuggestedMentions(req, res);
    }

    let users = [];

    switch (context) {
      // Group Chat
      case 'group': {
        if (!contextId) {
          return res.status(400).json({
            success: false,
            message: 'contextId (conversationId) is required for group context'
          });
        }

        const participants = await ConversationParticipant.findAll({
          where: {
            conversation_id: contextId,
            left_at: null,
            user_id: { [Op.ne]: userId }
          },
          include: [{
            model: User,
            as: 'user',
            where: {
              is_active: true,
              [Op.or]: [
                { username: { [Op.iLike]: `%${q.trim()}%` } },
                { fullName: { [Op.iLike]: `%${q.trim()}%` } }
              ]
            },
            attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified']
          }],
          limit: parseInt(limit)
        });
        users = participants.map(p => p.user).filter(Boolean);
        break;
      }

      // Community
      case 'community': {
        if (!contextId) {
          return res.status(400).json({
            success: false,
            message: 'contextId (communityId) is required for community context'
          });
        }

        const members = await CommunityMember.findAll({
          where: {
            community_id: contextId,
            is_banned: false,
            user_id: { [Op.ne]: userId }
          },
          include: [{
            model: User,
            as: 'user',
            where: {
              is_active: true,
              [Op.or]: [
                { username: { [Op.iLike]: `%${q.trim()}%` } },
                { fullName: { [Op.iLike]: `%${q.trim()}%` } }
              ]
            },
            attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified']
          }],
          limit: parseInt(limit)
        });
        users = members.map(m => m.user).filter(Boolean);
        break;
      }

      // Comment / Story / General
      case 'comment':
      case 'story':
      case 'general':
      default: {
        const following = await Follower.findAll({
          where: { followerId: userId, status: 'accepted' },
          attributes: ['followingId']
        });
        const followers = await Follower.findAll({
          where: { followingId: userId, status: 'accepted' },
          attributes: ['followerId']
        });

        const relevantIds = [
          ...following.map(f => f.followingId),
          ...followers.map(f => f.followerId)
        ].filter(id => id !== userId);

        const uniqueIds = [...new Set(relevantIds)];

        users = await User.findAll({
          where: {
            id: { [Op.in]: uniqueIds, [Op.ne]: userId },
            is_active: true,
            [Op.or]: [
              { username: { [Op.iLike]: `%${q.trim()}%` } },
              { fullName: { [Op.iLike]: `%${q.trim()}%` } }
            ]
          },
          attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified'],
          limit: parseInt(limit)
        });

        if (users.length < 5) {
          const moreUsers = await User.findAll({
            where: {
              id: { [Op.notIn]: [...uniqueIds, userId] },
              is_active: true,
              is_private: false,
              [Op.or]: [
                { username: { [Op.iLike]: `%${q.trim()}%` } },
                { fullName: { [Op.iLike]: `%${q.trim()}%` } }
              ]
            },
            attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified'],
            limit: parseInt(limit) - users.length
          });
          users = [...users, ...moreUsers];
        }
        break;
      }
    }

    const mappedUsers = users.map(user => ({
      _id: user.id,
      id: user.id,
      username: user.username,
      fullName: user.fullName,
      profile_pic_url: user.profile_pic_url,
      avatarUrl: user.profile_pic_url,
      is_verified: user.is_verified,
      isVerified: user.is_verified
    }));

    return res.status(200).json({
      success: true,
      data: { users: mappedUsers }
    });

  } catch (error) {
    console.error('❌ searchMentions error:', error);
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// ── GET MENTION NOTIFICATIONS ────────────────────────
const getMentionNotifications = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const userId = req.user.id;

    const { count, rows: notifications } = await Notification.findAndCountAll({
      where: {
        recipientId: userId,
        type: {
          [Op.in]: [
            'mention_comment',
            'mention_message',
            'mention_caption',
            'mention_story'
          ]
        }
      },
      include: [{
        model: User,
        as: 'sender',
        attributes: ['id', 'username', 'profile_pic_url', 'is_verified']
      }],
      order: [['createdAt', 'DESC']],
      limit,
      offset
    });

    return res.status(200).json({
      success: true,
      data: {
        notifications,
        total: count,
        page,
        limit
      }
    });

  } catch (error) {
    console.error('❌ getMentionNotifications error:', error);
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// ── MARK MENTION AS READ ──────────────────────────────
const markMentionRead = async (req, res) => {
  try {
    const { notificationId } = req.params;
    const userId = req.user.id;

    const notification = await Notification.findOne({
      where: { id: notificationId, recipientId: userId }
    });

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'Notification not found'
      });
    }

    await notification.update({ isRead: true });

    return res.status(200).json({
      success: true,
      message: 'Notification marked as read'
    });

  } catch (error) {
    console.error('❌ markMentionRead error:', error);
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

module.exports = {
  searchMentions,
  getMentionNotifications,
  markMentionRead
};
