// server/src/services/algorithm/suggestionsAlgorithm.js

const { Op } = require('sequelize');
const { User, Follower, Block, UserInterestProfile, Post } = require('../../models');

/**
 * Suggested Users Algorithm
 */
const getSuggestedUsers = async ({
  userId,
  limit = 20,
}) => {
  try {
    const following = await Follower.findAll({
      where: { followerId: userId, status: 'accepted' },
      attributes: ['followingId']
    });
    const followingIds = following.map(f => f.followingId);

    const followers = await Follower.findAll({
      where: { followingId: userId, status: 'accepted' },
      attributes: ['followerId']
    });
    const followerIds = followers.map(f => f.followerId);

    const blocks = await Block.findAll({
      where: { [Op.or]: [{ blockerId: userId }, { blockedId: userId }] },
      attributes: ['blockerId', 'blockedId']
    });
    const blockedIds = new Set(
      blocks.map(b => b.blockerId === userId ? b.blockedId : b.blockerId)
    );

    // Already excluded
    const excludeIds = new Set([
      userId,
      ...followingIds,
      ...Array.from(blockedIds),
    ]);

    // ── SIGNAL 1: MUTUAL FRIENDS (FOLLOWED BY FOLLOWING) ──
    const followingUsersData = await Follower.findAll({
      where: { followerId: { [Op.in]: followingIds }, status: 'accepted' },
      attributes: ['followingId', 'followerId']
    });

    const mutualCandidates = new Map(); // userId → mutualCount

    followingUsersData.forEach(follow => {
      const fId = follow.followingId;
      if (!excludeIds.has(fId)) {
        mutualCandidates.set(fId, (mutualCandidates.get(fId) || 0) + 1);
      }
    });

    // ── SIGNAL 2: FOLLOWS YOU BACK ──────────────────────
    const followsYouBackIds = followerIds.filter(id => !excludeIds.has(id));

    // ── SIGNAL 3: INTEREST MATCHING ────────────────────
    const userProfile = await UserInterestProfile.findOne({ where: { userId } });
    const topInterests = Object.entries(userProfile?.interests || {})
      .sort(([, a], [, b]) => b - a)
      .slice(0, 3)
      .map(([cat]) => cat);

    // ── STEP 4: GATHER & SCORE CANDIDATES ────────────────
    const candidatesMap = new Map();

    // Add mutuals
    for (const [cId, count] of mutualCandidates.entries()) {
      candidatesMap.set(cId, {
        userId: cId,
        mutualCount: count,
        followsBack: false,
        score: count * 15, // 15 points per mutual friend
      });
    }

    // Add follows you back
    followsYouBackIds.forEach(cId => {
      if (candidatesMap.has(cId)) {
        const item = candidatesMap.get(cId);
        item.followsBack = true;
        item.score += 40; // Heavy boost if they follow you
      } else {
        candidatesMap.set(cId, {
          userId: cId,
          mutualCount: 0,
          followsBack: true,
          score: 40,
        });
      }
    });

    // Interest similarity checks
    const interestProfiles = await UserInterestProfile.findAll({
      where: {
        userId: { [Op.notIn]: Array.from(excludeIds) }
      },
      limit: 100
    });

    interestProfiles.forEach(prof => {
      const cId = prof.userId;
      const otherInterests = prof.interests || {};
      
      let interestScore = 0;
      topInterests.forEach(cat => {
        interestScore += (otherInterests[cat] || 0) * 0.2; // weights
      });

      if (candidatesMap.has(cId)) {
        candidatesMap.get(cId).score += interestScore;
      } else if (interestScore > 10) {
        candidatesMap.set(cId, {
          userId: cId,
          mutualCount: 0,
          followsBack: false,
          score: interestScore,
        });
      }
    });

    // ── STEP 5: HYDRATE CANDIDATES ─────────────────────
    const sortedCandidates = Array.from(candidatesMap.values())
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);

    const hydratedUsers = [];
    for (const candidate of sortedCandidates) {
      const user = await User.findByPk(candidate.userId, {
        attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified']
      });

      if (user) {
        hydratedUsers.push({
          id: user.id,
          username: user.username,
          fullName: user.fullName,
          profile_pic_url: user.profile_pic_url,
          is_verified: user.is_verified,
          mutualCount: candidate.mutualCount,
          followsBack: candidate.followsBack,
          score: Math.round(candidate.score),
        });
      }
    }

    return hydratedUsers;

  } catch (error) {
    console.error('getSuggestedUsers error:', error.message);
    // Fallback: verified users or popular users
    const users = await User.findAll({
      where: { id: { [Op.ne]: userId } },
      attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified'],
      limit,
    });
    return users.map(u => ({
      id: u.id,
      username: u.username,
      fullName: u.fullName,
      profile_pic_url: u.profile_pic_url,
      is_verified: u.is_verified,
      mutualCount: 0,
      followsBack: false,
      score: 0,
    }));
  }
};

module.exports = { getSuggestedUsers };
