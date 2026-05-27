require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

if (process.env.DB_PASSWORD && !process.env.DB_PASS) {
  process.env.DB_PASS = process.env.DB_PASSWORD;
}

const { sequelize } = require('../src/config/database');
const { getAdsForFeed } = require('../src/services/ad.engine');
const User = require('../src/models/User.model');

// Load index.js to configure associations
require('../src/models/index.js');

async function run() {
  try {
    console.log('Connecting to database...');
    await sequelize.authenticate();
    console.log('Database connected.');

    // Fetch first user
    const user = await User.findOne();
    if (!user) {
      console.log('No user found in database to run test.');
      process.exit(0);
    }
    const userId = user.id;
    console.log(`Running test for User ID: ${userId} (${user.username}, age: ${user.age || 'unset'})`);

    const userProfile = {
      age: user.age || 25,
      gender: user.gender || 'all',
      interests: user.interests || [],
      location: user.location || {},
    };

    const ads = await getAdsForFeed({
      userId,
      placement: 'feed',
      count: 5,
      userProfile,
    });

    console.log(`\ngetAdsForFeed returned ${ads.length} ad(s):`);
    console.log(JSON.stringify(ads, null, 2));

    process.exit(0);
  } catch (error) {
    console.error('Error during run:', error);
    process.exit(1);
  }
}

run();
