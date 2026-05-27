const { Op } = require('sequelize');
const { Campaign, AdCreative, AdImpression, AdAnalyticsSnapshot, sequelize } = require('../models');

/**
 * Get ads to inject into a feed
 */
const getAdsForFeed = async ({
  userId,
  placement,        // 'feed' | 'reels' | 'stories'
  count = 2,        // how many ads to return
  userProfile = {}, // age, gender, interests, location
}) => {
  try {
    const now = new Date();
    // Maps placement string to campaign field (e.g. feed -> placementFeed)
    const placementField = `placement${placement.charAt(0).toUpperCase() + placement.slice(1)}`;

    // ── STEP 1: Find eligible campaigns ────────
    const eligibleCampaigns = await Campaign.findAll({
      where: {
        status: 'active',
        [placementField]: true,
        startDate: { [Op.lte]: now },
        [Op.or]: [
          { endDate: null },
          { endDate: { [Op.gte]: now } },
        ],
      },
      attributes: ['id', 'advertiserId', 'budgetType', 'budgetAmount', 'budgetSpent', 'bidAmount', 'objective', 'ageMin', 'ageMax', 'gender', 'interests', 'locations'],
    });

    if (eligibleCampaigns.length === 0) return [];

    // ── STEP 2: Filter by targeting ─────────────
    const targetedCampaigns = eligibleCampaigns.filter(campaign => {
      // Age check
      if (userProfile.age && campaign.ageMin !== undefined && campaign.ageMax !== undefined) {
        if (userProfile.age < campaign.ageMin || userProfile.age > campaign.ageMax) return false;
      }

      // Gender check
      if (campaign.gender && campaign.gender !== 'all' && userProfile.gender) {
        if (campaign.gender !== userProfile.gender) return false;
      }

      // Budget check — don't serve if budget exceeded
      if (campaign.budgetType === 'daily') {
        const todaySpent = campaign.budgetSpent || 0;
        if (todaySpent >= campaign.budgetAmount) return false;
      } else {
        // Lifetime budget check
        if (campaign.budgetSpent >= campaign.budgetAmount) {
          return false;
        }
      }

      return true;
    });

    if (targetedCampaigns.length === 0) return [];

    // ── STEP 3: Score each campaign (auction) ───
    const scoredCampaigns = targetedCampaigns.map(campaign => {
      // Base score = bid amount (or estimated bid)
      let score = campaign.bidAmount || 500; // default $5 CPM

      // Relevance score boost (0-2x)
      let relevanceBoost = 1.0;

      // Interest matching
      if (userProfile.interests && campaign.interests) {
        const interests = campaign.interests;
        const overlap = interests.filter(
          i => userProfile.interests.includes(i)
        ).length;
        relevanceBoost += (overlap * 0.1);
      }

      score = score * relevanceBoost;

      return { campaign, score };
    });

    // Sort by score (highest wins)
    scoredCampaigns.sort((a, b) => b.score - a.score);

    // ── STEP 4: Get ad creatives for winners ────
    const winners = scoredCampaigns.slice(0, count);
    const ads = [];

    for (const { campaign } of winners) {
      // Get ad type filter based on placement
      let typeFilter = {};
      if (placement === 'stories') {
        typeFilter = {
          type: { [Op.in]: ['story_image', 'story_video'] },
        };
      } else if (placement === 'reels') {
        typeFilter = { type: 'video' };
      } else {
        typeFilter = {
          type: { [Op.in]: ['image', 'video', 'carousel'] },
        };
      }

      const creative = await AdCreative.findOne({
        where: {
          campaignId: campaign.id,
          status: 'active',
          ...typeFilter,
        },
      });

      if (creative) {
        ads.push({
          adId: creative.id,
          campaignId: campaign.id,
          advertiserId: campaign.advertiserId,
          type: creative.type,
          placement,
          // Ad content
          advertiserName: creative.advertiserName,
          advertiserAvatarUrl: creative.advertiserAvatarUrl,
          primaryText: creative.primaryText,
          headline: creative.headline,
          description: creative.description,
          imageUrl: creative.imageUrl,
          videoUrl: creative.videoUrl,
          videoDuration: creative.videoDuration,
          videoThumbnailUrl: creative.videoThumbnailUrl,
          carouselCards: creative.carouselCards,
          ctaType: creative.ctaType,
          ctaUrl: creative.ctaUrl,
          storySwipeUpText: creative.storySwipeUpText,
          isSponsored: true,
        });
      }
    }

    return ads;

  } catch (error) {
    console.error('getAdsForFeed error:', error.message);
    return []; // Never break the feed
  }
};

/**
 * Record an ad event (impression, click, etc.)
 */
const recordAdEvent = async ({
  adCreativeId,
  campaignId,
  advertiserId,
  userId,
  action,
  placement,
  deviceType = 'android',
}) => {
  const transaction = await sequelize.transaction();
  try {
    // Calculate cost
    let costCharged = 0;

    if (action === 'impression') {
      // CPM billing: charge per 1000 impressions
      const campaign = await Campaign.findByPk(campaignId, {
        attributes: ['bidAmount'],
        transaction,
      });
      costCharged = Math.floor((campaign?.bidAmount || 500) / 1000);
    } else if (action === 'click' || action === 'cta_click') {
      // CPC billing: charge per click
      const campaign = await Campaign.findByPk(campaignId, {
        attributes: ['bidAmount', 'objective'],
        transaction,
      });
      if (campaign?.objective === 'traffic') {
        costCharged = campaign?.bidAmount || 50; // $0.50 per click
      }
    }

    // Record impression log
    await AdImpression.create({
      adCreativeId,
      campaignId,
      advertiserId,
      userId,
      action,
      placement,
      deviceType,
      costCharged,
    }, { transaction });

    // Update campaign metrics
    const campaignUpdates = {};
    const creativeUpdates = {};

    if (action === 'impression') {
      campaignUpdates.impressions = sequelize.literal('impressions + 1');
      campaignUpdates.budgetSpent = sequelize.literal(`budget_spent + ${costCharged}`);
      creativeUpdates.impressions = sequelize.literal('impressions + 1');
    } else if (action === 'click' || action === 'cta_click') {
      campaignUpdates.clicks = sequelize.literal('clicks + 1');
      campaignUpdates.budgetSpent = sequelize.literal(`budget_spent + ${costCharged}`);
      campaignUpdates.websiteClicks = sequelize.literal('website_clicks + 1');
      creativeUpdates.clicks = sequelize.literal('clicks + 1');
    } else if (action === 'skip') {
      campaignUpdates.skips = sequelize.literal('skips + 1');
      creativeUpdates.skips = sequelize.literal('skips + 1');
    } else if (action === 'video_start') {
      campaignUpdates.videoViews = sequelize.literal('video_views + 1');
      creativeUpdates.videoViews = sequelize.literal('video_views + 1');
    } else if (action === 'video_complete') {
      campaignUpdates.videoCompletions = sequelize.literal('video_completions + 1');
    }

    if (Object.keys(campaignUpdates).length > 0) {
      await Campaign.update(campaignUpdates, {
        where: { id: campaignId },
        transaction,
      });
    }

    if (Object.keys(creativeUpdates).length > 0) {
      await AdCreative.update(creativeUpdates, {
        where: { id: adCreativeId },
        transaction,
      });
    }

    // Update daily snapshot
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [snapshot, created] = await AdAnalyticsSnapshot.findOrCreate({
      where: { campaignId, date: today },
      defaults: {
        spend: costCharged,
        impressions: action === 'impression' ? 1 : 0,
        clicks: (action === 'click' || action === 'cta_click') ? 1 : 0,
        skips: action === 'skip' ? 1 : 0,
        videoViews: action === 'video_start' ? 1 : 0,
        videoCompletions: action === 'video_complete' ? 1 : 0,
        feedImpressions: (action === 'impression' && placement === 'feed') ? 1 : 0,
        reelImpressions: (action === 'impression' && placement === 'reels') ? 1 : 0,
        storyImpressions: (action === 'impression' && placement === 'stories') ? 1 : 0,
      },
      transaction,
    });

    if (!created) {
      const snapshotUpdates = {
        spend: sequelize.literal(`spend + ${costCharged}`),
      };
      if (action === 'impression') {
        snapshotUpdates.impressions = sequelize.literal('impressions + 1');
        if (placement === 'feed') {
          snapshotUpdates.feedImpressions = sequelize.literal('feed_impressions + 1');
        } else if (placement === 'reels') {
          snapshotUpdates.reelImpressions = sequelize.literal('reel_impressions + 1');
        } else if (placement === 'stories') {
          snapshotUpdates.storyImpressions = sequelize.literal('story_impressions + 1');
        }
      } else if (action === 'click' || action === 'cta_click') {
        snapshotUpdates.clicks = sequelize.literal('clicks + 1');
      } else if (action === 'skip') {
        snapshotUpdates.skips = sequelize.literal('skips + 1');
      } else if (action === 'video_start') {
        snapshotUpdates.videoViews = sequelize.literal('video_views + 1');
      } else if (action === 'video_complete') {
        snapshotUpdates.videoCompletions = sequelize.literal('video_completions + 1');
      }

      await AdAnalyticsSnapshot.update(snapshotUpdates, {
        where: { id: snapshot.id },
        transaction,
      });
    }

    await transaction.commit();
  } catch (error) {
    await transaction.rollback();
    console.error('recordAdEvent error:', error.message);
  }
};

module.exports = { getAdsForFeed, recordAdEvent };
