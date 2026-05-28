// server/src/services/algorithm/scoringEngine.js

const { Op } = require('sequelize');
const { ContentScoreCache, ContentInteraction, Post, Reel, User, Follower } = require('../../models');

/**
 * Calculate quality score for a piece of content
 * Based on engagement metrics relative to reach
 */
const calculateContentQualityScore = async (contentId, contentType) => {
  try {
    const now = new Date();

    // Check cache first
    const cached = await ContentScoreCache.findOne({
      where: {
        contentId,
        contentType,
        computedAt: { [Op.gt]: new Date(now.getTime() - 3600000) } // within 1 hour
      }
    });
    if (cached) {
      return cached;
    }

    let content;
    let authorFollowers = 1;
    let isVerified = false;

    if (contentType === 'post') {
      content = await Post.findOne({
        where: { id: contentId },
        include: [{ model: User, as: 'user', attributes: ['id', 'is_verified'] }]
      });
      if (content) {
        // Query author following stats count
        const followersCount = await Follower.count({
          where: { followingId: content.userId, status: 'accepted' }
        });
        authorFollowers = Math.max(1, followersCount);
        isVerified = content.user?.is_verified || false;
      }
    } else if (contentType === 'reel') {
      content = await Reel.findOne({
        where: { id: contentId },
        include: [{ model: User, as: 'user', attributes: ['id', 'is_verified'] }]
      });
      if (content) {
        const followersCount = await Follower.count({
          where: { followingId: content.userId, status: 'accepted' }
        });
        authorFollowers = Math.max(1, followersCount);
        isVerified = content.user?.is_verified || false;
      }
    }

    if (!content) return null;

    const ageHours = (now - content.createdAt) / 3600000;

    // ── ENGAGEMENT RATE ─────────────────────────
    const likesCount = content.likesCount || 0;
    const commentsCount = content.commentsCount || 0;
    const savesCount = 0; // standard fallback

    const likeRate = likesCount / authorFollowers;
    const commentRate = commentsCount / authorFollowers;

    const engagementRate = Math.min(100,
      (likeRate * 1.0 + commentRate * 2.0) * 100
    );

    // ── VELOCITY SCORE (recent momentum) ────────
    const recentLikes = await ContentInteraction.count({
      where: {
        contentId,
        action: 'like',
        createdAt: { [Op.gte]: new Date(now.getTime() - 3600000) },
      }
    });
    const recentComments = await ContentInteraction.count({
      where: {
        contentId,
        action: 'comment',
        createdAt: { [Op.gte]: new Date(now.getTime() - 3600000) },
      }
    });

    const likeVelocity = recentLikes; // per hour
    const commentVelocity = recentComments;
    const viralityScore = Math.min(100,
      (likeVelocity * 1 + commentVelocity * 2) * 10
    );

    // ── FRESHNESS SCORE ──────────────────────────
    // Decay: full score at 0h, half at 24h, near 0 at 72h
    const freshnessScore = Math.max(0,
      100 * Math.exp(-ageHours / 24)
    );

    // ── AUTHOR REPUTATION ────────────────────────
    const authorScore = Math.min(100,
      (Math.log10(authorFollowers + 1) / Math.log10(1000000)) * 100
    );
    const verifiedBoost = isVerified ? 10 : 0;
    const authorReputationScore = Math.min(100,
      authorScore + verifiedBoost
    );

    // ─── CONTENT SAFETY ALGORITHM (NSFW / HATE / SPAM FILTERS) ──
    const captionText = (content.caption || '').toLowerCase();
    const UNSAFE_KEYWORDS = ['buy followers', 'make money fast', 'click link in bio to win', 'hack accounts', 'cheap clickbait', 'offensive_term1', 'offensive_term2'];
    const containsUnsafeContent = UNSAFE_KEYWORDS.some(keyword => captionText.includes(keyword));

    // ─── COMPOSITE QUALITY SCORE ──────────────────
    let qualityScore = (
      engagementRate * 0.35 +
      viralityScore * 0.25 +
      freshnessScore * 0.25 +
      authorReputationScore * 0.15
    );

    if (containsUnsafeContent) {
      console.log(`⚠️ Content Safety Filter flagged post ${contentId} as unsafe. Zeroing score.`);
      qualityScore = 0;
    }

    const scoreData = {
      contentId,
      contentType,
      authorId: content.userId,
      qualityScore: Math.round(qualityScore),
      engagementRate: Math.round(engagementRate),
      viralityScore: Math.round(viralityScore),
      freshnessScore: Math.round(freshnessScore),
      authorReputationScore: Math.round(authorReputationScore),
      likeVelocity,
      commentVelocity,
      totalEngagements: likesCount + commentsCount,
      categories: content.categories || [],
      hashtags: [], // hashtags array extracted from caption
      computedAt: now,
      expiresAt: new Date(now.getTime() + 6 * 3600000), // Cache for 6 hours
    };

    // Cache the score in PostgreSQL
    await ContentScoreCache.upsert(scoreData);

    return scoreData;

  } catch (error) {
    console.error('calculateContentQualityScore error:', error.message);
    return null;
  }
};

/**
 * Calculate personalized score for user+content pair
 */
const calculatePersonalizedScore = ({
  contentScore,          // ContentScoreCache object
  userProfile,           // UserInterestProfile object
  isFollowing,
  isMutualFollow,
  authorRelationshipScore, // how much user engaged with author
  contentCategories = [],
  contentHashtags = [],
  alreadySeen,
  hoursOld,
}) => {
  let score = 0;

  // ── BASE QUALITY SCORE (20% weight) ──────────
  score += (contentScore?.qualityScore || 0) * 0.20;

  // ── RELATIONSHIP SIGNAL ──────────────────────
  // Instagram heavily favors people you're close to
  if (isFollowing) {
    score += 25;
    if (isMutualFollow) score += 15; // mutual = close friend
  }
  score += Math.min(20, (authorRelationshipScore || 0) * 0.1);

  // ── INTEREST MATCHING ────────────────────────
  if (userProfile && contentCategories && contentCategories.length > 0) {
    const interests = userProfile.interests || {};
    let interestBoost = 0;
    contentCategories.forEach(cat => {
      interestBoost += (interests[cat] || 0) * 0.3;
    });
    score += Math.min(20, interestBoost);
  }

  // ── HASHTAG AFFINITY ─────────────────────────
  if (userProfile && contentHashtags && contentHashtags.length > 0) {
    const userHashtags = new Map(
      (userProfile.recentHashtags || [])
        .map(h => [h.tag, h.score])
    );
    let hashtagBoost = 0;
    contentHashtags.forEach(tag => {
      const cleanTag = tag.toLowerCase().replace('#', '');
      hashtagBoost += (userHashtags.get(cleanTag) || 0) * 0.1;
    });
    score += Math.min(10, hashtagBoost);
  }

  // ── FRESHNESS ────────────────────────────────
  const freshnessBoost = Math.max(0,
    10 * Math.exp(-(hoursOld || 0) / 12)
  );
  score += freshnessBoost;

  // ── ENGAGEMENT VELOCITY ──────────────────────
  score += Math.min(10,
    (contentScore?.viralityScore || 0) * 0.1
  );

  // ── PENALTIES ────────────────────────────────
  if (alreadySeen) score -= 50; // heavily penalize seen content
  if (score < 0) score = 0;

  return Math.round(score * 100) / 100;
};

module.exports = {
  calculateContentQualityScore,
  calculatePersonalizedScore,
};
