const { sequelize } = require('../src/config/database');
const { getAdsForFeed } = require('../src/services/ad.engine');
const User = require('../src/models/User.model');
const Campaign = require('../src/models/Campaign.model');
const AdCreative = require('../src/models/AdCreative.model');

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

    // Let's query campaigns directly to print their details
    const campaigns = await Campaign.findAll({
      include: [
        {
          model: AdCreative,
          as: 'creatives',
        }
      ]
    });

    console.log(`\nTotal campaigns in DB: ${campaigns.length}`);
    for (let c of campaigns) {
      console.log(`- Campaign: "${c.name}" (ID: ${c.id})`);
      console.log(`  Status: ${c.status}`);
      console.log(`  Placements: Feed: ${c.placementFeed}, Reels: ${c.placementReels}, Stories: ${c.placementStories}`);
      console.log(`  Start: ${c.startDate}, End: ${c.endDate}`);
      console.log(`  Targeting: ${JSON.stringify(c.targeting)}`);
      console.log(`  Creatives count: ${c.creatives.length}`);
      for (let cr of c.creatives) {
        console.log(`    * Creative: Type: ${cr.type}, Status: ${cr.status}, URL: ${cr.imageUrl || cr.videoUrl}`);
      }
    }

    // Now call getAdsForFeed
    console.log('\nCalling getAdsForFeed...');
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
