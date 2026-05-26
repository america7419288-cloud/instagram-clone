const { Op } = require('sequelize');
const { AdAnalyticsSnapshot, Campaign, Advertiser } = require('../models');
const { successResponse, errorResponse } = require('../utils/response.utils');
const { sequelize } = require('../config/database');

const getCampaignAnalytics = async (req, res) => {
  try {
    const { id } = req.params;
    const { days = 7 } = req.query;

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - parseInt(days));
    startDate.setHours(0, 0, 0, 0);

    const snapshots = await AdAnalyticsSnapshot.findAll({
      where: {
        campaignId: id,
        date: { [Op.gte]: startDate },
      },
      order: [['date', 'ASC']],
    });

    const campaign = await Campaign.findByPk(id);

    // Calculate totals
    const totals = snapshots.reduce((acc, snap) => ({
      impressions: acc.impressions + (snap.impressions || 0),
      clicks: acc.clicks + (snap.clicks || 0),
      skips: acc.skips + (snap.skips || 0),
      videoViews: acc.videoViews + (snap.videoViews || 0),
      spend: acc.spend + (snap.spend || 0),
    }), {
      impressions: 0, clicks: 0, skips: 0,
      videoViews: 0, spend: 0,
    });

    const ctr = totals.impressions > 0
      ? ((totals.clicks / totals.impressions) * 100).toFixed(2)
      : '0.00';
    const cpm = totals.impressions > 0
      ? ((totals.spend / totals.impressions) * 1000).toFixed(2)
      : '0.00';
    const cpc = totals.clicks > 0
      ? (totals.spend / totals.clicks).toFixed(2)
      : '0.00';

    return successResponse(res, 200, 'Campaign analytics loaded', {
      campaign,
      snapshots,
      totals,
      metrics: { ctr, cpm, cpc },
    });
  } catch (error) {
    return errorResponse(res, 500, error.message);
  }
};

const getAnalyticsOverview = async (req, res) => {
  try {
    const advertiser = await Advertiser.findOne({
      where: { userId: req.user.id },
    });
    if (!advertiser) {
      return successResponse(res, 200, 'Advertiser overview loaded', {
        overview: {
          totalImpressions: 0,
          totalClicks: 0,
          totalSpend: 0,
          activeCampaigns: 0,
          totalCampaigns: 0,
          averageCtr: '0.00',
        },
        campaigns: [],
      });
    }

    const campaigns = await Campaign.findAll({
      where: { advertiserId: advertiser.id },
      attributes: ['id', 'name', 'status', 'budgetSpent', 'impressions', 'clicks'],
      order: [['createdAt', 'DESC']],
    });

    const totalImpressions = campaigns.reduce((s, c) => s + (c.impressions || 0), 0);
    const totalClicks = campaigns.reduce((s, c) => s + (c.clicks || 0), 0);
    const totalSpend = campaigns.reduce((s, c) => s + (c.budgetSpent || 0), 0);
    const activeCampaigns = campaigns.filter(c => c.status === 'active').length;

    const averageCtr = totalImpressions > 0
      ? ((totalClicks / totalImpressions) * 100).toFixed(2)
      : '0.00';

    return successResponse(res, 200, 'Advertiser overview loaded', {
      overview: {
        totalImpressions,
        totalClicks,
        totalSpend,
        activeCampaigns,
        totalCampaigns: campaigns.length,
        averageCtr,
      },
      campaigns,
    });
  } catch (error) {
    return errorResponse(res, 500, error.message);
  }
};

const getAdminAnalytics = async (req, res) => {
  try {
    const { days = 30 } = req.query;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - parseInt(days));
    startDate.setHours(0, 0, 0, 0);

    const snapshots = await AdAnalyticsSnapshot.findAll({
      where: {
        date: { [Op.gte]: startDate },
      },
      attributes: [
        'date',
        [sequelize.fn('SUM', sequelize.col('impressions')), 'totalImpressions'],
        [sequelize.fn('SUM', sequelize.col('clicks')), 'totalClicks'],
        [sequelize.fn('SUM', sequelize.col('spend')), 'totalSpend'],
        [sequelize.fn('SUM', sequelize.col('video_views')), 'totalVideoViews'],
      ],
      group: ['date'],
      order: [['date', 'ASC']],
      raw: true,
    });

    const totalRevenue = snapshots.reduce((s, d) => s + parseInt(d.totalSpend || 0), 0);
    const activeCampaigns = await Campaign.count({ where: { status: 'active' } });
    const pendingCampaigns = await Campaign.count({ where: { status: 'pending_review' } });

    return successResponse(res, 200, 'Admin analytics loaded', {
      snapshots,
      totalRevenue,
      activeCampaigns,
      pendingCampaigns,
    });
  } catch (error) {
    return errorResponse(res, 500, error.message);
  }
};

module.exports = {
  getCampaignAnalytics,
  getAnalyticsOverview,
  getAdminAnalytics,
};
