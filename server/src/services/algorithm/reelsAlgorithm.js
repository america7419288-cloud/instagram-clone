// server/src/services/algorithm/reelsAlgorithm.js

const { Op, fn, col } = require('sequelize');
const { sequelize } = require('../../config/database');
const { 
  Reel, User, UserInterestProfile, SeenContent, 
  ContentScoreCache, Follower, Block, ReelLike, ContentInteraction
} = require('../../models');

const _reelIncludes = (userId) => [
  {
    model: User,
    as: 'user',
    attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified'],
  },
  {
    model: ReelLike,
    as: 'likes',
    where: userId ? { userId } : undefined,
    required: false,
    attributes: ['userId'],
  }
];

/**
 * Reels Recommendation Algorithm
 */
const getRankedReels = async ({
  userId,
  page = 1,
  limit = 10,
  sessionId,
}) => {
  try {
    const CANDIDATE_POOL = limit * 10;

    // ── STEP 1: GET RELATIONS & PROFILES ───────────
    const [user, userProfile, seenContent] = await Promise.all([
      User.findByPk(userId),
      UserInterestProfile.findOne({ where: { userId } }),
      SeenContent.findOne({ where: { userId } }),
    ]);

    // Followers list
    const following = await Follower.findAll({
      where: { followerId: userId, status: 'accepted' },
      attributes: ['followingId']
    });
    const followingIds = following.map(f => f.followingId);

    // Blocked list
    const blocked = await Block.findAll({
      where: { [Op.or]: [{ blockerId: userId }, { blockedId: userId }] },
      attributes: ['blockerId', 'blockedId']
    });
    const blockedIds = new Set(
      blocked.map(b => b.blockerId === userId ? b.blockedId : b.blockerId)
    );

    const seenIds = new Set(seenContent?.contentIds || []);

    // ── STEP 2: CANDIDATE POOL (Following + Discovery) ──
    const [followingReels, discoverReels] = await Promise.all([
      // Reels from following
      Reel.findAll({
        where: {
          userId: { [Op.in]: followingIds, [Op.notIn]: Array.from(blockedIds) },
          createdAt: { [Op.gte]: new Date(Date.now() - 14 * 86400000) }, // 14 days
        },
        include: _reelIncludes(userId),
        order: [['createdAt', 'DESC']],
        limit: Math.floor(CANDIDATE_POOL * 0.4),
      }),

      // Discovery reels (not following, high engagement)
      Reel.findAll({
        where: {
          userId: { [Op.ne]: userId, [Op.notIn]: [...followingIds, ...Array.from(blockedIds)] },
          id: { [Op.notIn]: Array.from(seenIds) },
          likesCount: { [Op.gte]: 2 },
          createdAt: { [Op.gte]: new Date(Date.now() - 7 * 86400000) }, // 7 days
        },
        include: _reelIncludes(userId),
        order: [['playsCount', 'DESC'], ['likesCount', 'DESC']],
        limit: Math.floor(CANDIDATE_POOL * 0.6),
      }),
    ]);

    const allCandidates = [...followingReels, ...discoverReels];

    // ── STEP 3: COMPUTE REEL-SPECIFIC SCORES ──────
    const authorScoreMap = new Map(
      (userProfile?.recentAuthors || [])
        .map(a => [a.authorId, a.score])
    );

    const scoredReels = await Promise.all(
      allCandidates.map(async (reel) => {
        const authorId = reel.userId;
        const isFollowing = followingIds.includes(authorId);
        const hoursOld = (Date.now() - reel.createdAt) / 3600000;
        const alreadySeen = seenIds.has(reel.id);

        // Fetch watch stats completion rates
        const watchCounts = await ContentInteraction.findAll({
          where: {
            contentId: reel.id,
            action: { [Op.in]: ['video_watch_25', 'video_watch_50', 'video_watch_75', 'video_watch_100'] }
          },
          attributes: [
            'action',
            [fn('COUNT', col('id')), 'count']
          ],
          group: ['action'],
          raw: true
        });

        const stats = { watch25: 0, watch50: 0, watch75: 0, watch100: 0 };
        watchCounts.forEach(w => {
          if (w.action === 'video_watch_25') stats.watch25 = parseInt(w.count) || 0;
          if (w.action === 'video_watch_50') stats.watch50 = parseInt(w.count) || 0;
          if (w.action === 'video_watch_75') stats.watch75 = parseInt(w.count) || 0;
          if (w.action === 'video_watch_100') stats.watch100 = parseInt(w.count) || 0;
        });

        const totalViews = Math.max(reel.playsCount || 1, stats.watch25, 1);
        const completionRate = (stats.watch100 / totalViews) * 100;

        let reelScore = 0;

        // #1: Watch completion (35% weight)
        reelScore += completionRate * 0.35;

        // #2: Shares per view (25% weight) — strongest signal
        const shareRate = (reel.sharesCount || 0) / totalViews;
        reelScore += Math.min(25, shareRate * 100 * 0.25);

        // #3: Likes per view (15% weight)
        const likeRate = (reel.likesCount || 0) / totalViews;
        reelScore += Math.min(15, likeRate * 100 * 0.15);

        // #4: Comments per view (10% weight)
        const commentRate = (reel.commentsCount || 0) / totalViews;
        reelScore += Math.min(10, commentRate * 50 * 0.10);

        // #5: Following relationship (10% weight)
        if (isFollowing) reelScore += 10;

        // #6: Interest matching (5% weight)
        if (userProfile && reel.categories) {
          const interests = userProfile.interests || {};
          let interestScore = 0;
          reel.categories.forEach(cat => {
            interestScore += (interests[cat] || 0) * 0.05;
          });
          reelScore += Math.min(5, interestScore);
        }

        // ── PENALTIES ─────────────────────────
        if (alreadySeen) reelScore -= 30;
        if (hoursOld > 48) reelScore -= 5;

        return {
          reel,
          score: Math.max(0, reelScore),
        };
      })
    );

    // ── STEP 4: APPLY DIVERSITY RULES ─────────────
    const authorCount = new Map();
    const diversified = scoredReels
      .sort((a, b) => b.score - a.score)
      .filter(({ reel }) => {
        const authorId = reel.userId;
        const count = authorCount.get(authorId) || 0;
        if (count >= 2) return false; // max 2 reels per author
        authorCount.set(authorId, count + 1);
        return true;
      })
      .map(s => s.reel);

    // ── STEP 5: PAGINATE & UPDATE SEEN ────────────
    const paginated = diversified.slice((page - 1) * limit, page * limit);

    const newSeenIds = paginated.map(r => r.id);
    if (newSeenIds.length > 0) {
      const updatedSeenIds = Array.from(new Set([...Array.from(seenIds), ...newSeenIds]));
      await SeenContent.upsert({
        userId,
        contentIds: updatedSeenIds.slice(-500),
        expiresAt: new Date(Date.now() + 30 * 86400000), // 30 days
      });
    }

    return {
      reels: paginated,
      page,
      hasMore: diversified.length > page * limit,
    };

  } catch (error) {
    console.error('getRankedReels error:', error.message);
    // Fallback
    const reels = await Reel.findAll({
      include: _reelIncludes(userId),
      order: [['createdAt', 'DESC']],
      offset: (page - 1) * limit,
      limit,
    });
    return { reels, page, hasMore: reels.length === limit };
  }
};

module.exports = { getRankedReels };
