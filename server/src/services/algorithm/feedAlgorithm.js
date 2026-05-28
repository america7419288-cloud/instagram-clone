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
 * Home Feed Algorithm — Truly Infinite Scroll
 *
 * Strategy:
 *   1. Pull ranked posts from people the user follows (primary pool)
 *   2. Always top-up the page with explore/suggested posts so every page is full
 *   3. hasMore = true as long as the page returned any posts at all
 *      (explore pool is always available and essentially unlimited)
 *   4. SeenContent prevents repeats across pages
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
    const selfAndFollowingIds = [userId, ...followingIds];
    const mutedIds = new Set(muted.map(m => m.mutedUserId));
    const blockedIds = new Set(
      blocked.map(b => b.blocker_id === userId ? b.blocked_id : b.blocker_id)
    );
    const seenIds = new Set(seenContent?.contentIds || []);

    const authorScoreMap = new Map(
      (userProfile?.recentAuthors || []).map(a => [a.authorId, a.score])
    );

    // ── STEP 2: GATHER CANDIDATE POSTS FROM FOLLOWING ────────
    const filteredFollowingIds = selfAndFollowingIds.filter(
      id => !mutedIds.has(id) && !blockedIds.has(id)
    );

    // Expand lookback as the user scrolls deeper
    // page 1→10d, 2→20d, 3→30d, 5→60d, 8→all time
    const daysBack = page >= 8 ? 3650 : page >= 5 ? 60 : page >= 3 ? 30 : page >= 2 ? 20 : 10;
    const CANDIDATE_POOL = limit * (8 + page * 2);

    const candidates = await Post.findAll({
      where: {
        userId: { [Op.in]: filteredFollowingIds },
        isArchived: { [Op.or]: [false, null] },
        createdAt: { [Op.gte]: new Date(Date.now() - daysBack * 86400000) },
      },
      include: _postIncludes(userId),
      order: [['createdAt', 'DESC']],
      limit: CANDIDATE_POOL,
    });

    // ── STEP 3: SCORE EACH CANDIDATE ─────────────
    const scoredPosts = await Promise.all(
      candidates.map(async (post) => {
        const authorId = post.userId;
        const isFollowing = followingIds.includes(authorId);

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

        let contentScore = await ContentScoreCache.findOne({
          where: { contentId: post.id, contentType: 'post' }
        });
        if (!contentScore) {
          contentScore = await calculateContentQualityScore(post.id, 'post');
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

        let formatBoost = 0;
        if (userProfile?.formatPreferences) {
          const prefs = userProfile.formatPreferences;
          const isVideo = post.mediaFiles?.some(m => m.mediaType === 'video');
          const isCarousel = (post.mediaFiles?.length || 0) > 1;
          if (isCarousel) formatBoost = (prefs.carousel || 50) * 0.1;
          else if (isVideo) formatBoost = (prefs.video || 50) * 0.1;
          else formatBoost = (prefs.image || 50) * 0.1;
        }

        return { post, score: personalizedScore + formatBoost, alreadySeen };
      })
    );

    // ── STEP 4: APPLY DIVERSITY RULES ────────────
    const diversifiedPosts = _applyDiversityRules(scoredPosts);

    // ── STEP 5: PAGINATE FOLLOWING POSTS ─────────────────────
    const allSorted = diversifiedPosts.sort((a, b) => b.score - a.score);
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
        contentIds: updatedSeenIds.slice(-500),
        expiresAt: new Date(now.getTime() + 30 * 86400000),
      });
    }

    // ── STEP 7: ALWAYS FILL PAGE WITH EXPLORE/SUGGESTED ──────
    // If following posts don't fill the full page, top-up with explore content.
    // This is the key to infinite scroll — explore pool is always available.
    const allSeenSoFar = new Set([...seenIds, ...newSeenIds]);
    if (sorted.length < limit) {
      const needed = limit - sorted.length;
      const suggestedPosts = await _getSuggestedPostsForFeed({
        userId,
        userProfile,
        count: needed,
        seenIds: allSeenSoFar,
        blockedIds,
        page, // used to vary explore content per page
      });

      if (sorted.length === 0) {
        // Following pool fully exhausted — entire page is explore content
        sorted = suggestedPosts.map(p =>
          p.get ? { ...p.get({ plain: true }), isSuggested: true } : { ...p, isSuggested: true }
        );
      } else {
        // Interleave: every 3 following posts, inject 1 suggested
        sorted = _interleaveContent(sorted, suggestedPosts);
      }
    }

    // ── STEP 8: INJECT AD TARGETING CARD ──────────
    // Note: client-side home_page.dart fetches ads separately and interleaves them.
    // Injecting ads directly here causes PostModel parsing failure and duplicate interleaving.
    const finalItems = sorted;

    // hasMore = true as long as we returned any posts.
    // The explore pool is always available so we never truly run out.
    const hasMore = finalItems.filter(p => !p.isAd).length > 0;

    return { posts: finalItems, page, hasMore };

  } catch (error) {
    console.error('getFeedPosts error:', error.message);
    return _getFallbackFeed(userId, page, limit);
  }
};

/**
 * Apply diversity rules to prevent author flooding
 * Max 2 posts from the same person per page
 */
const _applyDiversityRules = (scoredPosts) => {
  const authorPostCount = new Map();
  const MAX_PER_AUTHOR = 2;
  return scoredPosts.filter(({ post }) => {
    const count = authorPostCount.get(post.userId) || 0;
    if (count >= MAX_PER_AUTHOR) return false;
    authorPostCount.set(post.userId, count + 1);
    return true;
  });
};

/**
 * Get suggested/explore posts from non-following users.
 * Falls back gracefully when the user has no interest profile.
 * Uses page offset so deeper pages surface different content.
 */
const _getSuggestedPostsForFeed = async ({
  userId,
  userProfile,
  count,
  seenIds,
  blockedIds,
  page = 1,
}) => {
  const blockedArray = Array.from(blockedIds);
  const seenArray = Array.from(seenIds);

  const topInterests = Object.entries(userProfile?.interests || {})
    .sort(([, a], [, b]) => b - a)
    .slice(0, 5)
    .map(([cat]) => cat);

  // Build where clause — fall back to popular posts if no interests
  const baseWhere = {
    userId: {
      [Op.ne]: userId,
      ...(blockedArray.length > 0 ? { [Op.notIn]: blockedArray } : {}),
    },
    isArchived: { [Op.or]: [false, null] },
    ...(seenArray.length > 0 ? { id: { [Op.notIn]: seenArray } } : {}),
  };

  // Try interest-based first
  if (topInterests.length > 0) {
    try {
      const interestPosts = await Post.findAll({
        where: {
          ...baseWhere,
          categories: { [Op.overlap]: topInterests },
        },
        include: _postIncludes(userId),
        order: [
          ['likesCount', 'DESC'],
          ['createdAt', 'DESC'],
        ],
        limit: count,
        offset: (page - 1) * count,
      });
      if (interestPosts.length > 0) return interestPosts;
    } catch (_) {
      // categories column may not support overlap — fall through
    }
  }

  // Fall back: popular recent posts globally
  return Post.findAll({
    where: baseWhere,
    include: _postIncludes(userId),
    order: [
      ['likesCount', 'DESC'],
      ['createdAt', 'DESC'],
    ],
    limit: count,
    offset: (page - 1) * count,
  });
};

/**
 * Interleave suggested posts into the following feed.
 * Ratio: every 3 following posts → 1 suggested post.
 */
const _interleaveContent = (primary, secondary) => {
  const result = [];
  let secIndex = 0;
  primary.forEach((post, i) => {
    result.push(post);
    if ((i + 1) % 3 === 0 && secIndex < secondary.length) {
      const p = secondary[secIndex];
      result.push({
        ...(p.get ? p.get({ plain: true }) : p),
        isSuggested: true,
      });
      secIndex++;
    }
  });
  // Append any remaining suggested posts
  while (secIndex < secondary.length) {
    const p = secondary[secIndex];
    result.push({
      ...(p.get ? p.get({ plain: true }) : p),
      isSuggested: true,
    });
    secIndex++;
  }
  return result;
};

/**
 * Chronological fallback feed (used when the algorithm errors out)
 */
const _getFallbackFeed = async (userId, page, limit) => {
  try {
    const following = await Follower.findAll({
      where: { followerId: userId, status: 'accepted' },
      attributes: ['followingId'],
    });
    const followingIds = following.map(f => f.followingId);

    const posts = await Post.findAll({
      where: {
        userId: { [Op.in]: [userId, ...followingIds] },
        isArchived: { [Op.or]: [false, null] },
      },
      include: _postIncludes(userId),
      order: [['createdAt', 'DESC']],
      offset: (page - 1) * limit,
      limit,
    });

    // If following posts are exhausted, fall back to global popular posts
    if (posts.length === 0 && page > 1) {
      const explorePosts = await Post.findAll({
        where: {
          userId: { [Op.ne]: userId },
          isArchived: { [Op.or]: [false, null] },
        },
        include: _postIncludes(userId),
        order: [['likesCount', 'DESC'], ['createdAt', 'DESC']],
        offset: (page - 1) * limit,
        limit,
      });
      return { posts: explorePosts, page, hasMore: explorePosts.length > 0 };
    }

    return { posts, page, hasMore: posts.length > 0 };
  } catch (err) {
    console.error('_getFallbackFeed error:', err.message);
    return { posts: [], page, hasMore: false };
  }
};

module.exports = { getFeedPosts };
