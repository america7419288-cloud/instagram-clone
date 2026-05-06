const { Block } = require('../models');
const { Op } = require('sequelize');

/**
 * Gets a list of IDs for users that the given user has blocked or been blocked by.
 * @param {string} userId - The ID of the current user.
 * @returns {Promise<string[]>} - Array of user IDs.
 */
const getBlockedUserIds = async (userId) => {
  if (!userId) return [];
  
  const blocks = await Block.findAll({
    where: {
      [Op.or]: [
        { blocker_id: userId },
        { blocked_id: userId }
      ]
    },
    attributes: ['blocker_id', 'blocked_id'],
    raw: true
  });

  const blockedIds = new Set();
  const searchId = userId.toString();

  blocks.forEach(b => {
    const blockerIdStr = b.blocker_id.toString();
    const blockedIdStr = b.blocked_id.toString();

    if (blockerIdStr === searchId) {
      blockedIds.add(blockedIdStr);
    } else {
      blockedIds.add(blockerIdStr);
    }
  });

  return Array.from(blockedIds);
};

module.exports = {
  getBlockedUserIds
};
