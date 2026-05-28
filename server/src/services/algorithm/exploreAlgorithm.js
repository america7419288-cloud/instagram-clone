// server/src/services/algorithm/exploreAlgorithm.js

const { Op } = require('sequelize');
const { 
  Post, User, UserInterestProfile, SeenContent, 
  ContentScoreCache, Follower, Block, PostMedia, Like, SavedPost
} = require('../../models');

const _postIncludes = (userId) => [
  {
    model: User,
    as: 'user',
    attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified'],
  },
  {
    model: PostMedia,
    as: 'mediaFiles',
    attributes: ['id', 'url', 'thumbnailUrl', 'mediaType', 'publicId', 'duration', 'width', 'height', 'order'],
  },
  {
    model: Like,
    as: 'likes',
    where: userId ? { userId } : undefined,
    required: false,
    attributes: ['userId'],
  },
  {
    model: SavedPost,
    as: 'saves',
    where: userId ? { userId } : undefined,
    required: false,
    attributes: ['userId'],
  },
];

/**
 * Explore Recommendation Algorithm
 */
const getExploreContent = async ({
  userId,
  page = 1,
  limit = 24,
  category = 'all',
}) => {
  try {
    // ── STEP 1: GET RELATIONSHIPS & INTERESTS ─────
    const [following, blocked, userProfile, seenContent] = await Promise.all([
      Follower.findAll({
        where: { followerId: userId, status: 'accepted' },
        attributes: ['followingId']
      }),
      Block.findAll({
        where: { [Op.or]: [{ blockerId: userId }, { blockedId: userId }] },
        attributes: ['blockerId', 'blockedId']
      }),
      UserInterestProfile.findOne({ where: { userId } }),
      SeenContent.findOne({ where: { userId } }),
    ]);

    const followingIds = following.map(f => f.followingId);
    
    const blockedIds = new Set(
      blocked.map(b => b.blockerId === userId ? b.blockedId : b.blockerId)
    );

    const seenIds = new Set(seenContent?.contentIds || []);

    // Get top user interests
    const interests = userProfile?.interests || {};
    const topCategories = Object.entries(interests)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 5)
      .map(([cat]) => cat);

    // ── STEP 2: BUILD CANDIDATE QUERY ─────────────
    // Query constraints: not own, not following, not blocked, not seen, not archived
    const queryConditions = {
      userId: { [Op.ne]: userId, [Op.notIn]: [...followingIds, ...Array.from(blockedIds)] },
      isArchived: { [Op.or]: [false, null] },
      id: { [Op.notIn]: Array.from(seenIds) },
    };

    if (category !== 'all') {
      if (category === 'reels') {
        queryConditions.hasVideo = true; // posts with video
      } else {
        // Categories overlap query
        queryConditions.categories = { [Op.overlap]: [category] };
      }
    }

    const POOL = limit * 5;
    const candidates = await Post.findAll({
      where: queryConditions,
      include: _postIncludes(userId),
      order: [['likesCount', 'DESC'], ['createdAt', 'DESC']],
      limit: POOL,
    });

    // ── STEP 3: SCORE EACH CANDIDATE ─────────────
    const scored = candidates.map(post => {
      let score = 0;

      // Quality signals
      const likesCount = post.likesCount || 0;
      const commentsCount = post.commentsCount || 0;
      const totalEngagements = likesCount + commentsCount * 2;
      score += Math.min(40, totalEngagements * 2);

      // Interest match
      const postCats = post.categories || [];
      const catOverlap = postCats.filter(c => topCategories.includes(c)).length;
      score += catOverlap * 10;

      // Hashtag match
      const userHashtagMap = new Map(
        (userProfile?.recentHashtags || [])
          .map(h => [h.tag, h.score])
      );
      const hashtags = post.caption ? (post.caption.match(/#[a-zA-Z0-9_]+/g) || []) : [];
      hashtags.forEach(tag => {
        const cleanTag = tag.toLowerCase().replace('#', '');
        score += Math.min(5, (userHashtagMap.get(cleanTag) || 0) * 0.1);
      });

      // Freshness (explore shows newer content)
      const hoursOld = (Date.now() - post.createdAt) / 3600000;
      score += Math.max(0, 20 * Math.exp(-hoursOld / 48));

      // Virality
      const velocity = likesCount / Math.max(hoursOld, 1);
      score += Math.min(20, velocity);

      return { post, score };
    });

    // ── STEP 4: SORT & PAGINATE ───────────────────
    const sorted = scored
      .sort((a, b) => b.score - a.score)
      .slice((page - 1) * limit, page * limit)
      .map(s => s.post);

    // Update seen content
    const newSeenIds = sorted.map(p => p.id);
    if (newSeenIds.length > 0) {
      const updatedSeenIds = Array.from(new Set([...Array.from(seenIds), ...newSeenIds]));
      await SeenContent.upsert({
        userId,
        contentIds: updatedSeenIds.slice(-500),
        expiresAt: new Date(Date.now() + 30 * 86400000), // 30 days
      });
    }

    return {
      items: sorted,
      page,
      hasMore: sorted.length === limit,
    };

  } catch (error) {
    console.error('getExploreContent error:', error.message);
    const items = await Post.findAll({
      where: { isArchived: { [Op.or]: [false, null] } },
      include: _postIncludes(userId),
      order: [['likesCount', 'DESC']],
      offset: (page - 1) * limit,
      limit,
    });
    return { items, page, hasMore: items.length === limit };
  }
};

module.exports = { getExploreContent };
