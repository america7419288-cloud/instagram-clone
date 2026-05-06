// server/trigger_test_notif.js
require('dotenv').config();
const { User } = require('./src/models');
const notificationService = require('./src/services/notification.service');

async function trigger() {
  try {
    // 1. Find "ankit" (recipient)
    const recipient = await User.findOne({ where: { username: 'ankit' } });
    if (!recipient) {
      console.log('❌ Recipient "ankit" not found');
      process.exit(1);
    }

    // 2. Find any other user (sender)
    const sender = await User.findOne({ 
      where: { 
        username: { [require('sequelize').Op.ne]: 'ankit' } 
      } 
    });

    if (!sender) {
      console.log('❌ No other user found to be the sender. Please create another account first.');
      process.exit(1);
    }

    console.log(`🔔 Triggering follow notification from "${sender.username}" to "${recipient.username}"...`);
    
    const notif = await notificationService.notifyFollow(sender.id, recipient.id);
    
    if (notif) {
      console.log('✅ Notification created and push sent (if token was valid)');
      console.log('Notification ID:', notif.id);
    } else {
      console.log('⚠️ Notification created but push might have failed (check server logs)');
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Error triggering notification:', error);
    process.exit(1);
  }
}

trigger();
