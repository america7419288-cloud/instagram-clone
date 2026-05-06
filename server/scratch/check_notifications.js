// scratch/check_notifications.js
require('dotenv').config({ path: '.env' });
const { Notification } = require('../src/models');

async function check() {
  try {
    const notifications = await Notification.findAll({
      limit: 1,
      order: [['createdAt', 'DESC']]
    });
    console.log(JSON.stringify(notifications, null, 2));
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

check();
