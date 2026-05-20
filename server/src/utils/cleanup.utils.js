// server/src/utils/cleanup.utils.js
// Runs periodically to clean up expired story media

const { Story, Message } = require('../models');
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

// Clean up expired disappearing messages
const cleanupExpiredMessages = async () => {
  try {
    console.log('🧹 Starting expired message cleanup...');
    const deletedCount = await Message.destroy({
      where: {
        expires_at: { [Op.lte]: new Date() }
      }
    });

    if (deletedCount > 0) {
      console.log(`🧹 Disappearing Messages Sweeper: Removed ${deletedCount} expired messages.`);
    } else {
      console.log('🧹 Disappearing Messages Sweeper: No expired messages to clean.');
    }
  } catch (error) {
    console.error('❌ Message cleanup job error:', error.message);
  }
};

// Schedule cleanup to run periodically
const startCleanupJob = () => {
  // Run once on startup
  cleanupExpiredStories();
  cleanupExpiredMessages();

  // Then run every hour (3600000 ms)
  const storyInterval = setInterval(
    cleanupExpiredStories,
    60 * 60 * 1000
  );

  // Then run every 60 seconds (60000 ms)
  const messageInterval = setInterval(
    cleanupExpiredMessages,
    60 * 1000
  );

  console.log('⏰ Story cleanup job scheduled (every hour)');
  console.log('⏰ Disappearing messages cleanup job scheduled (every 60 seconds)');

  return { storyInterval, messageInterval };
};

module.exports = {
  cleanupExpiredStories,
  cleanupExpiredMessages,
  startCleanupJob,
};