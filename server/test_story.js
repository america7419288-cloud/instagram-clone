// server/test_story.js
require('dotenv').config();
const { Follower } = require('./src/models');

async function test() {
  try {
    console.log('Fetching Followers...');
    const list = await Follower.findAll({ limit: 5, raw: true });
    console.log('Raw Followers:', list);
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

test();
