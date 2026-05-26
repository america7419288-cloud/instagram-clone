const { getAdsForFeed, recordAdEvent } = require('../services/ad.engine');
const { AdCreative, Advertiser } = require('../models');
const { uploadImageToCloudinary, uploadVideoToCloudinary } = require('../services/upload.service');
const { successResponse, errorResponse } = require('../utils/response.utils');

// ── GET FEED ADS ─────────────────────────────
const getFeedAds = async (req, res) => {
  try {
    const { count = 2 } = req.query;
    const userId = req.user.id;

    const userProfile = {
      age: req.user.age || 25,
      gender: req.user.gender || 'all',
      interests: req.user.interests || [],
      location: req.user.location || {},
    };

    const ads = await getAdsForFeed({
      userId,
      placement: 'feed',
      count: parseInt(count) || 2,
      userProfile,
    });

    return successResponse(res, 200, 'Feed ads loaded', { ads });
  } catch (error) {
    return errorResponse(res, 500, error.message);
  }
};

const getStoryAds = async (req, res) => {
  try {
    const ads = await getAdsForFeed({
      userId: req.user.id,
      placement: 'stories',
      count: 1,
      userProfile: {
        age: req.user.age || 25,
        gender: req.user.gender || 'all',
        interests: req.user.interests || [],
        location: req.user.location || {},
      },
    });
    return successResponse(res, 200, 'Story ads loaded', { ads });
  } catch (error) {
    return errorResponse(res, 500, error.message);
  }
};

const getReelAds = async (req, res) => {
  try {
    const ads = await getAdsForFeed({
      userId: req.user.id,
      placement: 'reels',
      count: 1,
      userProfile: {
        age: req.user.age || 25,
        gender: req.user.gender || 'all',
        interests: req.user.interests || [],
        location: req.user.location || {},
      },
    });
    return successResponse(res, 200, 'Reel ads loaded', { ads });
  } catch (error) {
    return errorResponse(res, 500, error.message);
  }
};

// ── TRACK AD EVENT ───────────────────────────
const trackAdEvent = async (req, res) => {
  try {
    const {
      adId,         // adCreativeId
      campaignId,
      advertiserId,
      action,
      placement,
    } = req.body;

    // Fire and forget — don't block response
    recordAdEvent({
      adCreativeId: adId,
      campaignId,
      advertiserId,
      userId: req.user.id,
      action,
      placement,
      deviceType: req.headers['x-device-type'] || 'android',
    });

    return successResponse(res, 200, 'Ad event tracked');
  } catch (error) {
    // Don't break client app for tracking errors
    return successResponse(res, 200, 'Ad event tracked');
  }
};

// ── CREATE AD CREATIVE ───────────────────────
const createCreative = async (req, res) => {
  try {
    const { campaignId } = req.params;
    const {
      type,
      advertiserName,
      advertiserAvatarUrl,
      primaryText,
      headline,
      description,
      ctaType,
      ctaUrl,
      storySwipeUpText,
      storyOverlayColor,
      carouselCards, // JSON string
    } = req.body;

    const advertiser = await Advertiser.findOne({
      where: { userId: req.user.id },
    });

    if (!advertiser) {
      return errorResponse(res, 403, 'No advertiser account found');
    }

    let imageUrl = null;
    let videoUrl = null;
    let videoThumbnailUrl = null;
    let imageWidth = null;
    let imageHeight = null;
    let videoDuration = null;

    // Upload image
    if (req.files?.image?.[0]) {
      const result = await uploadImageToCloudinary(
        req.files.image[0].buffer,
        req.files.image[0].mimetype,
        'instagram-clone/ads/images'
      );
      imageUrl = result.url;
      imageWidth = result.width;
      imageHeight = result.height;
    }

    // Upload video
    if (req.files?.video?.[0]) {
      const result = await uploadVideoToCloudinary(
        req.files.video[0].buffer,
        req.files.video[0].mimetype,
        'instagram-clone/ads/videos'
      );
      videoUrl = result.url;
      videoDuration = result.duration;
      videoThumbnailUrl = result.thumbnailUrl;
    }

    // Upload custom thumbnail
    if (req.files?.thumbnail?.[0]) {
      const thumbResult = await uploadImageToCloudinary(
        req.files.thumbnail[0].buffer,
        req.files.thumbnail[0].mimetype,
        'instagram-clone/ads/thumbnails'
      );
      videoThumbnailUrl = thumbResult.url;
    }

    // Handle carousel images
    let parsedCarouselCards = [];
    if (type === 'carousel' && req.files?.carouselImages) {
      const parsedCards = JSON.parse(carouselCards || '[]');
      for (let i = 0; i < req.files.carouselImages.length; i++) {
        const file = req.files.carouselImages[i];
        const result = await uploadImageToCloudinary(
          file.buffer,
          file.mimetype,
          'instagram-clone/ads/carousel'
        );
        parsedCarouselCards.push({
          imageUrl: result.url,
          headline: parsedCards[i]?.headline || '',
          description: parsedCards[i]?.description || '',
          ctaUrl: parsedCards[i]?.ctaUrl || ctaUrl,
        });
      }
    }

    const creative = await AdCreative.create({
      campaignId,
      advertiserId: advertiser.id,
      type,
      imageUrl,
      imageWidth,
      imageHeight,
      videoUrl,
      videoDuration,
      videoThumbnailUrl,
      carouselCards: parsedCarouselCards,
      advertiserName: advertiserName || advertiser.businessName,
      advertiserAvatarUrl: advertiserAvatarUrl || advertiser.logoUrl,
      primaryText,
      headline,
      description,
      ctaType: ctaType || 'learn_more',
      ctaUrl,
      storySwipeUpText: storySwipeUpText || 'See more',
      storyOverlayColor: storyOverlayColor || '#000000',
      status: 'active',
    });

    return successResponse(res, 201, 'Creative created successfully', creative);
  } catch (error) {
    return errorResponse(res, 500, error.message);
  }
};

// ── CREATE ADVERTISER ────────────────────────
const createAdvertiser = async (req, res) => {
  try {
    const {
      businessName,
      businessEmail,
      businessCategory,
      businessWebsite,
    } = req.body;
    const userId = req.user.id;

    const existing = await Advertiser.findOne({ where: { userId } });
    if (existing) {
      return errorResponse(res, 400, 'Advertiser account already exists');
    }

    // Support uploading business logo
    let logoUrl = null;
    if (req.file) {
      const upload = await uploadImageToCloudinary(req.file.buffer, req.file.mimetype, 'instagram-clone/ads/logos');
      logoUrl = upload.url;
    }

    const advertiser = await Advertiser.create({
      userId,
      businessName,
      businessEmail,
      businessCategory,
      businessWebsite,
      logoUrl,
      isVerified: false,
      status: 'active',
    });

    return successResponse(res, 201, 'Advertiser registered successfully', advertiser);
  } catch (error) {
    return errorResponse(res, 500, error.message);
  }
};

const getMyAdvertiser = async (req, res) => {
  try {
    const advertiser = await Advertiser.findOne({ where: { userId: req.user.id } });
    if (!advertiser) return errorResponse(res, 404, 'Advertiser profile not found');
    return successResponse(res, 200, 'Advertiser profile loaded', advertiser);
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

const updateAdvertiser = async (req, res) => {
  try {
    const updateData = { ...req.body };
    if (req.file) {
      const upload = await uploadImageToCloudinary(req.file.buffer, req.file.mimetype, 'instagram-clone/ads/logos');
      updateData.logoUrl = upload.url;
    }

    const [updatedCount] = await Advertiser.update(updateData, {
      where: { userId: req.user.id },
    });

    if (updatedCount === 0) return errorResponse(res, 404, 'Advertiser profile not found');

    const advertiser = await Advertiser.findOne({ where: { userId: req.user.id } });
    return successResponse(res, 200, 'Advertiser profile updated', advertiser);
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

const getCreatives = async (req, res) => {
  try {
    const creatives = await AdCreative.findAll({
      where: { campaignId: req.params.campaignId },
    });
    return successResponse(res, 200, 'Creatives loaded', creatives);
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

const updateCreative = async (req, res) => {
  try {
    await AdCreative.update(req.body, {
      where: { id: req.params.id },
    });
    const creative = await AdCreative.findByPk(req.params.id);
    return successResponse(res, 200, 'Creative updated', creative);
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

const deleteCreative = async (req, res) => {
  try {
    // Soft delete to archived state
    await AdCreative.update(
      { status: 'archived' },
      { where: { id: req.params.id } }
    );
    return successResponse(res, 200, 'Creative archived successfully');
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

module.exports = {
  getFeedAds,
  getStoryAds,
  getReelAds,
  trackAdEvent,
  createCreative,
  createAdvertiser,
  getMyAdvertiser,
  updateAdvertiser,
  getCreatives,
  updateCreative,
  deleteCreative,
};
