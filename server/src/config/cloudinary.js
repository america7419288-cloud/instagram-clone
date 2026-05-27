const cloudinary = require('cloudinary').v2;
require('dotenv').config();

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
  secure: true,
});

const secondaryConfig = {
  cloud_name: 'dm1fulk5c',
  api_key: '398391396318295',
  api_secret: 'LBc9hFDJS6OA7hZuPORXifFZYrE',
  secure: true,
};

const testCloudinary = async () => {
  try {
    const result = await cloudinary.api.ping();
    if (result.status === 'ok') {
      console.log('✅ Primary Cloudinary connected successfully!');
    }
  } catch (error) {
    console.error('❌ Primary Cloudinary connection failed:', error.message);
    console.error('   Check your CLOUDINARY credentials in .env');
  }

  try {
    const result = await cloudinary.api.ping(secondaryConfig);
    if (result.status === 'ok') {
      console.log('✅ Secondary Cloudinary connected successfully!');
    }
  } catch (error) {
    console.error('❌ Secondary Cloudinary connection failed:', error.message);
  }
};

module.exports = { cloudinary, secondaryConfig, testCloudinary };