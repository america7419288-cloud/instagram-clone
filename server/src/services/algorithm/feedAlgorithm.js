// server/src/services/algorithm/feedAlgorithm.js

const { Op } = require('sequelize');
const { 
  Post, User, UserInterestProfile, SeenContent, 
  ContentScoreCache, Follower, Block, MutedAccount,
  PostMedia, Like, SavedPost
} = require('../../models');

const { 
  calculatePersonalizedScore, 
  calculateContentQualityScore 
} = require('./scoringEngine');

const { getAdsForFeed } = require('../ad.engine');

/**
 * Standard includes for post queries in Sequelize
 */
const _postIncludes = (userId) => [
  {
    model: User,
    as: 'user',
    attributes: [
      'id',
      'username',
      'fullName',
      'profile_pic_url',
      'is_verified',
      'is_private',
    ],
  },
  {
    model: PostMedia,
    as: 'mediaFiles',
    attributes: [
      'id',
      'url',
      'thumbnailUrl',
      'mediaType',
      'publicId',
      'duration',
      'width',
      'height',
      'order',
    ],
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
 * Home Feed Algorithm
 */
const getFeedPosts = async ({
  userId,
  page = 1,
  limit = 20,
  sessionId,
}) => {
  try {
    // ── STEP 1: GET USER DATA ─────────────────────
    const [following, muted, blocked, userProfile, seenContent] = await Promise.all([
      Follower.findAll({
        where: { followerId: userId, status: 'accepted' },
        attributes: ['followingId']
      }),
      MutedAccount.findAll({
        where: { userId },
        attributes: ['mutedUserId', 'muteStories']
      }),
      Block.findAll({
        where: { [Op.or]: [{ blocker_id: userId }, { blocked_id: userId }] },
        attributes: ['blocker_id', 'blocked_id']
      }),
      UserInterestProfile.findOne({ where: { userId } }),
      SeenContent.findOne({ where: { userId } }),
    ]);

    const followingIds = following.map(f => f.followingId);
    
    // Include own posts in candidate pool
    const selfAndFollowingIds = [userId, ...followingIds];

    const mutedIds = new Set(muted.map(m => m.mutedUserId));
    
    const blockedIds = new Set(
      blocked.map(b => b.blocker_id === userId ? b.blocked_id : b.blocker_id)
    );

    const seenIds = new Set(seenContent?.contentIds || []);

    // Build author relationship scores map
    const authorScoreMap = new Map(
      (userProfile?.recentAuthors || [])
        .map(a => [a.authorId, a.score])
    );

    // ── STEP 2: GATHER CANDIDATE POSTS ───────────
    const filteredCandidateUserIds = selfAndFollowingIds.filter(
      id => !mutedIds.has(id) && !blockedIds.has(id)
    );

    // Expand the time window as the user scrolls deeper so feed is truly infinite:
    // page 1 → 10 days, page 2 → 20 days, page 3+ → 30 days, page 5+ → 60 days, page 8+ → all time
    const daysBack = page >= 8 ? 3650 : page >= 5 ? 60 : page >= 3 ? 30 : page >= 2 ? 20 : 10;
    const CANDIDATE_POOL = limit * (8 + page * 2); // grow pool on deeper pages

    const candidates = await Post.findAll({
      where: {
        userId: { [Op.in]: filteredCandidateUserIds },
        isArchived: { [Op.or]: [false, null] },
        createdAt: { [Op.gte]: new Date(Date.now() - daysBack * 86400000) },
      },
      include: _postIncludes(userId),
      order: [['createdAt', 'DESC']],
      limit: CANDIDATE_POOL
    });

    // ── STEP 3: SCORE EACH CANDIDATE ─────────────
    const scoredPosts = await Promise.all(
      candidates.map(async (post) => {
        const authorId = post.userId;
        const isFollowing = followingIds.includes(authorId);
        
        // Check mutual following
        const mutualFollowCount = await Follower.count({
          where: {
            [Op.or]: [
              { followerId: userId, followingId: authorId, status: 'accepted' },
              { followerId: authorId, followingId: userId, status: 'accepted' }
            ]
          }
        });
        const isMutualFollow = mutualFollowCount >= 2;

        const hoursOld = (Date.now() - post.createdAt) / 3600000;
        const alreadySeen = seenIds.has(post.id);

        // Get or compute quality score
        let contentScore = await ContentScoreCache.findOne({
          where: { contentId: post.id, contentType: 'post' }
        });
        if (!contentScore) {
          contentScore = await calculateContentQualityScore(
            post.id, 'post'
          );
        }

        const hashtags = post.caption ? (post.caption.match(/#[a-zA-Z0-9_]+/g) || []) : [];

        const personalizedScore = calculatePersonalizedScore({
          contentScore,
          userProfile,
          isFollowing,
          isMutualFollow,
          authorRelationshipScore: authorScoreMap.get(authorId) || 0,
          contentCategories: post.categories || [],
          contentHashtags: hashtags.slice(0, 5),
          alreadySeen,
          hoursOld,
        });

        // Format preference boost
        let formatBoost = 0;
        if (userProfile?.formatPreferences) {
          const prefs = userProfile.formatPreferences;
          const isVideo = post.mediaFiles?.some(m => m.mediaType === 'video');
          const isCarousel = (post.mediaFiles?.length || 0) > 1;

          if (isCarousel) formatBoost = (prefs.carousel || 50) * 0.1;
          else if (isVideo) formatBoost = (prefs.video || 50) * 0.1;
          else formatBoost = (prefs.image || 50) * 0.1;
        }

        return {
          post,
          score: personalizedScore + formatBoost,
          alreadySeen,
        };
      })
    );

    // ── STEP 4: APPLY DIVERSITY RULES ────────────
    const diversifiedPosts = _applyDiversityRules(scoredPosts);

    // ── STEP 5: SORT AND PAGINATE ─────────────────
    const allSorted = diversifiedPosts.sort((a, b) => b.score - a.score);
    const paginatedCount = allSorted.slice((page - 1) * limit, page * limit).length;
    const hasMore = allSorted.length > page * limit; // true pages remain
    let sorted = allSorted
      .slice((page - 1) * limit, page * limit)
      .map(s => s.post);

    // ── STEP 6: UPDATE SEEN CONTENT ──────────────
    const newSeenIds = sorted.map(s => s.id);
    if (newSeenIds.length > 0) {
      const updatedSeenIds = Array.from(new Set([...Array.from(seenIds), ...newSeenIds]));
      
      const now = new Date();
      await SeenContent.upsert({
        userId,
        contentIds: updatedSeenIds.slice(-500), // keep last 500 seen
        expiresAt: new Date(now.getTime() + 30 * 86400000), // 30 days
      });
    }

    // ── STEP 7: INJECT SUGGESTED CONTENT ─────────
    // If not enough following posts, inject explore posts
    if (sorted.length < limit / 2) {
      const suggestedPosts = await _getSuggestedPostsForFeed({
        userId,
        userProfile,
        count: limit - sorted.length,
        seenIds: new Set([...seenIds, ...newSeenIds]),
        blockedIds,
      });
      // Interleave: every 3 following posts, 1 suggested
      sorted = _interleaveContent(sorted, suggestedPosts);
    }

    // ── STEP 8: INJECT AD TARGETING CARD ──────────
    // Inject highly targeted advertiser ads based on profile interests every 4 posts
    let finalItems = [];
    if (sorted.length > 0) {
      const userInterests = Object.entries(userProfile?.interests || {})
        .filter(([, val]) => val > 20)
        .map(([key]) => key);

      const ads = await getAdsForFeed({
        userId,
        placement: 'feed',
        count: Math.ceil(sorted.length / 4),
        userProfile: {
          gender: userProfile?.gender,
          interests: userInterests,
        }
      });

      let adIndex = 0;
      sorted.forEach((post, idx) => {
        finalItems.push(post);
        if ((idx + 1) % 4 === 0 && adIndex < ads.length) {
          finalItems.push({
            ...ads[adIndex],
            isAd: true,
            id: ads[adIndex].adId, // match signature
          });
          adIndex++;
        }
      });
    } else {
      finalItems = sorted;
    }

    return {
      posts: finalItems,
      page,
      hasMore,
    };

  } catch (error) {
    console.error('getFeedPosts error:', error.message);
    // Fallback: chronological feed
    return _getFallbackFeed(userId, page, limit);
  }
};

/**
 * Apply diversity rules to prevent author flooding
 * Instagram shows max 2 posts from same person per session
 */
const _applyDiversityRules = (scoredPosts) => {
  const authorPostCount = new Map();
  const MAX_PER_AUTHOR = 2;

  return scoredPosts.filter(({ post }) => {
    const authorId = post.userId;
    const count = authorPostCount.get(authorId) || 0;
    if (count >= MAX_PER_AUTHOR) return false;
    authorPostCount.set(authorId, count + 1);
    return true;
  });
};

/**
 * Get suggested posts from non-following users
 * for injection into low-content feeds
 */
const _getSuggestedPostsForFeed = async ({
  userId,
  userProfile,
  count,
  seenIds,
  blockedIds,
}) => {
  const topInterests = Object.entries(
    userProfile?.interests || {}
  )
  .sort(([, a], [, b]) => b - a)
  .slice(0, 3)
  .map(([cat]) => cat);

  const suggestedPosts = await Post.findAll({
    where: {
      userId: { [Op.ne]: userId, [Op.notIn]: Array.from(blockedIds) },
      isArchived: { [Op.or]: [false, null] },
      id: { [Op.notIn]: Array.from(seenIds) },
      categories: topInterests.length > 0
        ? { [Op.overlap]: topInterests } // overlap matching arrays
        : { [Op.ne]: null },
      likesCount: { [Op.gte]: 5 },
      createdAt: { [Op.gte]: new Date(Date.now() - 3 * 86400000) },
    },
    include: _postIncludes(userId),
    order: [['likesCount', 'DESC']],
    limit: count,
  });

  return suggestedPosts;
};

const _interleaveContent = (primary, secondary) => {
  const result = [];
  let secIndex = 0;
  primary.forEach((post, i) => {
    result.push(post);
    if ((i + 1) % 3 === 0 && secIndex < secondary.length) {
      result.push({ ...secondary[secIndex].get({ plain: true }), isSuggested: true });
      secIndex++;
    }
  });
  while (result.length < primary.length + secondary.length && secIndex < secondary.length) {
    result.push({ ...secondary[secIndex].get({ plain: true }), isSuggested: true });
    secIndex++;
  }
  return result;
};

const _getFallbackFeed = async (userId, page, limit) => {
  const following = await Follower.findAll({
    where: { followerId: userId, status: 'accepted' },
    attributes: ['followingId'],
  });
  const followingIds = following.map((f) => f.followingId);
  const posts = await Post.findAll({
    where: {
      userId: { [Op.in]: [userId, ...followingIds] },
      isArchived: { [Op.or]: [false, null] },
    },
    include: _postIncludes(userId),
    order: [['createdAt', 'DESC']],
    offset: (page - 1) * limit,
    limit: limit,
  });
  return { posts, page, hasMore: posts.length === limit };
};

module.exports = { getFeedPosts };
