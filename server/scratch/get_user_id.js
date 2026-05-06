// scratch/get_user_id.js
require('dotenv').config({ path: '.env' });
const { User } = require('../src/models');

async function get() {
  try {
    const user = await User.findOne({ attributes: ['id', 'username'] });
    if (user) {
      console.log('USER_ID=' + user.id);
      console.log('USERNAME=' + user.username);
    } else {
      console.log('NO_USER_FOUND');
    }
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

get();
