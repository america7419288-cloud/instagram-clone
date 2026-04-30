const cloudinary = require('cloudinary').v2;
require('dotenv').config();
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});
const testCloudinary = async () => {
  try {
    const result = await cloudinary.api.ping();
    if (result.status === 'ok') {
      console.log('✅ Cloudinary connected successfully!');
    }
  } catch (error) {
    console.error('❌ Cloudinary connection failed:', error.message);
    console.error('   Check your CLOUDINARY credentials in .env');
  }
};

module.exports = { cloudinary, testCloudinary };