// scratch/test_push_trigger.js
require('dotenv').config({ path: '.env' });
const { Post, User } = require('../src/models');

const TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImFiNWVhOWY2LWMzOGQtNGZjZS1iZGM3LWJkOWFkNGI4ZTUwNCIsInVzZXJuYW1lIjoiam9obl9kb2UzIiwiaWF0IjoxNzc3NzkzMjUyLCJleHAiOjE3Nzc3OTY4NTJ9.SQ7rFnof997MpPdqIqEZltrXUvI0V1c3D1h7iv4UM18';
const BASE_URL = 'http://127.0.0.1:5000/api/v1';

async function test() {
  try {
    // 1. Find a post NOT owned by john_doe3
    const post = await Post.findOne({
      where: { userId: { [require('sequelize').Op.ne]: 'ab5ea9f6-c38d-4fce-bdc7-bd9ad4b8e504' } },
      include: [{ model: User, as: 'user', attributes: ['id', 'username', 'fcmToken'] }]
    });

    if (!post) {
      console.log('No eligible post found to like.');
      process.exit(0);
    }

    console.log(`Liking post ${post.id} (Owner: ${post.user.username})...`);
    
    // Ensure the owner has an FCM token for the test
    await post.user.update({ fcmToken: 'fake-recipient-token-987654321' });

    const likeRes = await fetch(`${BASE_URL}/posts/${post.id}/like`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${TOKEN}` }
    });

    console.log('Like Status:', likeRes.status);
    const data = await likeRes.json();
    console.log('Like Response:', data);

    if (data.success) {
      console.log('\n✅ Triggered! Check server logs for push delivery attempt.');
    }

    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

test();
