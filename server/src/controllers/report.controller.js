// server/src/controllers/report.controller.js

const { Report, User, Message } = require('../models');
const { successResponse, errorResponse } = require('../utils/response.utils');
const { Op } = require('sequelize');

/**
 * @desc    Report a user
 * @route   POST /api/v1/reports/user/:userId
 * @access  Private
 */
const reportUser = async (req, res) => {
  try {
    const reporterId = req.user.id;
    const { userId } = req.params;
    const { report_type, description } = req.body;

    if (!report_type) {
      return errorResponse(res, 400, 'Report type is required.');
    }

    if (reporterId === userId) {
      return errorResponse(res, 400, 'You cannot report yourself.');
    }

    // 1. Verify target user exists
    const userToReport = await User.findByPk(userId);
    if (!userToReport) {
      return errorResponse(res, 404, 'User to report not found.');
    }

    // 2. Cooldown check: Max 1 report per target user per 24 hours
    const cooldownPeriod = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const existingReport = await Report.findOne({
      where: {
        reported_by: reporterId,
        reported_user_id: userId,
        created_at: {
          [Op.gt]: cooldownPeriod,
        },
      },
    });

    if (existingReport) {
      return errorResponse(
        res,
        429,
        'You have already reported this user within the last 24 hours.'
      );
    }

    // 3. Create report
    const report = await Report.create({
      reported_by: reporterId,
      reported_user_id: userId,
      report_type,
      description: description || '',
      status: 'pending',
    });

    return successResponse(res, 201, 'User reported successfully.', {
      report_id: report.id,
      status: report.status,
    });
  } catch (error) {
    console.error('Error reporting user:', error);
    return errorResponse(res, 500, error.message || 'Failed to submit user report.');
  }
};

/**
 * @desc    Report a specific message
 * @route   POST /api/v1/reports/message/:messageId
 * @access  Private
 */
const reportMessage = async (req, res) => {
  try {
    const reporterId = req.user.id;
    const { messageId } = req.params;
    const { report_type, description } = req.body;

    if (!report_type) {
      return errorResponse(res, 400, 'Report type is required.');
    }

    // 1. Verify target message exists
    const message = await Message.findByPk(messageId);
    if (!message) {
      return errorResponse(res, 404, 'Message to report not found.');
    }

    if (message.sender_id === reporterId) {
      return errorResponse(res, 400, 'You cannot report your own message.');
    }

    // 2. Cooldown check: Max 1 report per message per 24 hours
    const cooldownPeriod = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const existingReport = await Report.findOne({
      where: {
        reported_by: reporterId,
        reported_message_id: messageId,
        created_at: {
          [Op.gt]: cooldownPeriod,
        },
      },
    });

    if (existingReport) {
      return errorResponse(
        res,
        429,
        'You have already reported this message within the last 24 hours.'
      );
    }

    // 3. Create report
    const report = await Report.create({
      reported_by: reporterId,
      reported_user_id: message.sender_id, // Report the sender of the message
      reported_message_id: messageId,
      report_type,
      description: description || '',
      status: 'pending',
    });

    return successResponse(res, 201, 'Message reported successfully.', {
      report_id: report.id,
      status: report.status,
    });
  } catch (error) {
    console.error('Error reporting message:', error);
    return errorResponse(res, 500, error.message || 'Failed to submit message report.');
  }
};

module.exports = {
  reportUser,
  reportMessage,
};
