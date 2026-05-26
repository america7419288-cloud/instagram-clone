const express = require('express');
const router = express.Router();

const { protect, adminOnly } = require('../middleware/auth.middleware');
const { uploadPostMedia } = require('../services/upload.service');

const adCtrl = require('../controllers/ad.controller');
const campaignCtrl = require('../controllers/campaign.controller');
const analyticsCtrl = require('../controllers/adAnalytics.controller');

// ── PUBLIC / USER AD LOADING & TRACKING ────────
router.get('/feed', protect, adCtrl.getFeedAds);
router.post('/track', protect, adCtrl.trackAdEvent);
router.get('/stories', protect, adCtrl.getStoryAds);
router.get('/reels', protect, adCtrl.getReelAds);

// ── ADVERTISER SETTINGS ───────────────────────
router.post('/advertiser', protect, uploadPostMedia.single('logo'), adCtrl.createAdvertiser);
router.get('/advertiser/me', protect, adCtrl.getMyAdvertiser);
router.put('/advertiser', protect, uploadPostMedia.single('logo'), adCtrl.updateAdvertiser);

// ── CAMPAIGNS ─────────────────────────────────
router.get('/campaigns', protect, campaignCtrl.getMyCampaigns);
router.post('/campaigns', protect, campaignCtrl.createCampaign);
router.get('/campaigns/:id', protect, campaignCtrl.getCampaign);
router.put('/campaigns/:id', protect, campaignCtrl.updateCampaign);
router.delete('/campaigns/:id', protect, campaignCtrl.deleteCampaign);
router.post('/campaigns/:id/pause', protect, campaignCtrl.pauseCampaign);
router.post('/campaigns/:id/resume', protect, campaignCtrl.resumeCampaign);

// ── AD CREATIVES ──────────────────────────────
router.get('/campaigns/:campaignId/creatives', protect, adCtrl.getCreatives);
router.post(
  '/campaigns/:campaignId/creatives',
  protect,
  uploadPostMedia.fields([
    { name: 'image', maxCount: 1 },
    { name: 'video', maxCount: 1 },
    { name: 'thumbnail', maxCount: 1 },
    { name: 'carouselImages', maxCount: 10 },
  ]),
  adCtrl.createCreative
);
router.put('/creatives/:id', protect, adCtrl.updateCreative);
router.delete('/creatives/:id', protect, adCtrl.deleteCreative);

// ── ANALYTICS ─────────────────────────────────
router.get('/campaigns/:id/analytics', protect, analyticsCtrl.getCampaignAnalytics);
router.get('/analytics/overview', protect, analyticsCtrl.getAnalyticsOverview);

// ── ADMIN ROUTES (YOU - APP OWNER) ──────────
router.get('/admin/campaigns', protect, adminOnly, campaignCtrl.getAllCampaigns);
router.post('/admin/campaigns/:id/approve', protect, adminOnly, campaignCtrl.approveCampaign);
router.post('/admin/campaigns/:id/reject', protect, adminOnly, campaignCtrl.rejectCampaign);
router.get('/admin/analytics', protect, adminOnly, analyticsCtrl.getAdminAnalytics);
router.post('/admin/campaigns', protect, adminOnly, campaignCtrl.createOwnerCampaign);

module.exports = router;
