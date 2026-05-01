// server/src/utils/cleanup.utils.js
// Runs periodically to clean up expired story media

const { Story } = require('../models');
const { deleteFromCloudinary } = require('../services/upload.service');
const { Op } = require('sequelize');

// Clean up expired stories from Cloudinary
// Run this every hour in production
const cleanupExpiredStories = async () => {
  try {
    console.log('🧹 Starting expired story cleanup...');

    // Find stories expired more than 1 hour ago
    // (give some buffer time)
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

    const expiredStories = await Story.findAll({
      where: {
        expires_at: { [Op.lt]: oneHourAgo },
        cloudinary_public_id: { [Op.ne]: null },
      },
      attributes: ['id', 'cloudinary_public_id'],
    });

    console.log(
      `   Found ${expiredStories.length} expired stories to clean`
    );

    let deletedCount = 0;

    for (const story of expiredStories) {
      try {
        // Delete from Cloudinary
        await deleteFromCloudinary(story.cloudinary_public_id);

        // Clear cloudinary_public_id so we don't try again
        await story.update({ cloudinary_public_id: null });

        deletedCount++;
      } catch (err) {
        console.error(
          `   Failed to clean story ${story.id}:`,
          err.message
        );
      }
    }

    console.log(
      `✅ Cleanup done: ${deletedCount}/${expiredStories.length} cleaned`
    );

  } catch (error) {
    console.error('❌ Cleanup job error:', error.message);
  }
};

// Schedule cleanup to run every hour
const startCleanupJob = () => {
  // Run once on startup
  cleanupExpiredStories();

  // Then run every hour (3600000 ms)
  const interval = setInterval(
    cleanupExpiredStories,
    60 * 60 * 1000
  );

  console.log('⏰ Story cleanup job scheduled (every hour)');

  return interval;
};

module.exports = {
  cleanupExpiredStories,
  startCleanupJob,
};