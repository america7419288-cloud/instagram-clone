const { Campaign, Advertiser } = require('../models');
const { successResponse, errorResponse } = require('../utils/response.utils');

const createCampaign = async (req, res) => {
  try {
    const {
      name,
      objective,
      budget, // budget: { type: 'daily'|'lifetime', amount: cents }
      bidStrategy,
      bidAmount,
      schedule, // schedule: { startDate, endDate, timezone, activeDays, activeHoursStart, activeHoursEnd }
      targeting,
      placements,
    } = req.body;
    const userId = req.user.id;

    const advertiser = await Advertiser.findOne({ where: { userId } });
    if (!advertiser) {
      return errorResponse(res, 403, 'Create an advertiser account first');
    }

    // Validate budget minimum
    if (!budget?.amount || budget.amount < 100) {
      return errorResponse(res, 400, 'Minimum budget is $1.00 (100 cents)');
    }

    const campaign = await Campaign.create({
      advertiserId: advertiser.id,
      name,
      objective,
      budgetType: budget.type || 'daily',
      budgetAmount: budget.amount,
      budgetSpent: 0,
      bidStrategy: bidStrategy || 'lowest_cost',
      bidAmount: bidAmount || null,
      startDate: schedule?.startDate ? new Date(schedule.startDate) : new Date(),
      endDate: schedule?.endDate ? new Date(schedule.endDate) : null,
      timezone: schedule?.timezone || 'UTC',
      activeDays: schedule?.activeDays || [0, 1, 2, 3, 4, 5, 6],
      activeHoursStart: schedule?.activeHoursStart !== undefined ? schedule.activeHoursStart : 0,
      activeHoursEnd: schedule?.activeHoursEnd !== undefined ? schedule.activeHoursEnd : 23,
      targeting: targeting || {},
      placementFeed: placements?.feed !== undefined ? placements.feed : true,
      placementReels: placements?.reels !== undefined ? placements.reels : true,
      placementStories: placements?.stories !== undefined ? placements.stories : true,
      placementExplore: placements?.explore !== undefined ? placements.explore : false,
      status: 'pending_review',
    });

    return successResponse(res, 201, 'Campaign created and submitted for review', campaign);
  } catch (error) {
    return errorResponse(res, 500, error.message);
  }
};

// ── OWNER: Create campaign without review ────
const createOwnerCampaign = async (req, res) => {
  try {
    const {
      name,
      objective,
      budget,
      schedule,
      targeting,
      placements,
    } = req.body;

    // Get or create app owner advertiser
    let ownerAdvertiser = await Advertiser.findOne({
      where: { isAppOwner: true },
    });

    if (!ownerAdvertiser) {
      ownerAdvertiser = await Advertiser.create({
        businessName: 'App Owner',
        businessEmail: process.env.OWNER_EMAIL || 'admin@instagram.com',
        businessCategory: 'entertainment',
        isAppOwner: true,
        isVerified: true,
        status: 'active',
      });
    }

    const campaign = await Campaign.create({
      advertiserId: ownerAdvertiser.id,
      name,
      objective: objective || 'awareness',
      budgetType: budget?.type || 'lifetime',
      budgetAmount: budget?.amount || 99999999, // default large budget
      budgetSpent: 0,
      startDate: schedule?.startDate ? new Date(schedule.startDate) : new Date(),
      endDate: schedule?.endDate ? new Date(schedule.endDate) : null,
      targeting: targeting || {},
      placementFeed: placements?.feed !== undefined ? placements.feed : true,
      placementReels: placements?.reels !== undefined ? placements.reels : true,
      placementStories: placements?.stories !== undefined ? placements.stories : true,
      placementExplore: placements?.explore !== undefined ? placements.explore : false,
      status: 'active', // Auto-approved for owner
    });

    return successResponse(res, 201, 'Owner campaign created successfully', campaign);
  } catch (error) {
    return errorResponse(res, 500, error.message);
  }
};

const getMyCampaigns = async (req, res) => {
  try {
    const { page = 1, limit = 20, status } = req.query;
    const advertiser = await Advertiser.findOne({
      where: { userId: req.user.id },
    });

    if (!advertiser) {
      return successResponse(res, 200, 'Advertiser campaigns loaded', { campaigns: [] });
    }

    const query = { advertiserId: advertiser.id };
    if (status) query.status = status;

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const campaigns = await Campaign.findAll({
      where: query,
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset,
    });

    return successResponse(res, 200, 'Advertiser campaigns loaded', { campaigns });
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

const getCampaign = async (req, res) => {
  try {
    const campaign = await Campaign.findByPk(req.params.id);
    if (!campaign) return errorResponse(res, 404, 'Campaign not found');
    return successResponse(res, 200, 'Campaign loaded', campaign);
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

const updateCampaign = async (req, res) => {
  try {
    await Campaign.update(req.body, {
      where: { id: req.params.id },
    });
    const campaign = await Campaign.findByPk(req.params.id);
    return successResponse(res, 200, 'Campaign updated', campaign);
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

const deleteCampaign = async (req, res) => {
  try {
    await Campaign.destroy({
      where: { id: req.params.id },
    });
    return successResponse(res, 200, 'Campaign deleted successfully');
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

const pauseCampaign = async (req, res) => {
  try {
    await Campaign.update(
      { status: 'paused' },
      { where: { id: req.params.id } }
    );
    return successResponse(res, 200, 'Campaign paused successfully');
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

const resumeCampaign = async (req, res) => {
  try {
    await Campaign.update(
      { status: 'active' },
      { where: { id: req.params.id } }
    );
    return successResponse(res, 200, 'Campaign resumed successfully');
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

// ─── ADMIN DECK ─────────────────────────────
const getAllCampaigns = async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    const query = {};
    if (status) query.status = status;

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const campaigns = await Campaign.findAll({
      where: query,
      include: [
        {
          model: Advertiser,
          as: 'advertiser',
          attributes: ['businessName', 'businessEmail'],
        },
      ],
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset,
    });

    return successResponse(res, 200, 'All campaigns loaded', { campaigns });
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

const approveCampaign = async (req, res) => {
  try {
    await Campaign.update(
      {
        status: 'active',
        reviewedAt: new Date(),
        reviewedBy: req.user.id,
      },
      { where: { id: req.params.id } }
    );
    return successResponse(res, 200, 'Campaign approved');
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

const rejectCampaign = async (req, res) => {
  try {
    const { reason } = req.body;
    await Campaign.update(
      {
        status: 'rejected',
        rejectionReason: reason || 'Policy violation',
        reviewedAt: new Date(),
        reviewedBy: req.user.id,
      },
      { where: { id: req.params.id } }
    );
    return successResponse(res, 200, 'Campaign rejected');
  } catch (e) {
    return errorResponse(res, 500, e.message);
  }
};

module.exports = {
  createCampaign,
  createOwnerCampaign,
  getMyCampaigns,
  getCampaign,
  updateCampaign,
  deleteCampaign,
  pauseCampaign,
  resumeCampaign,
  getAllCampaigns,
  approveCampaign,
  rejectCampaign,
};
