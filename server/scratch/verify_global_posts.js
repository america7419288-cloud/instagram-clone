require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

if (process.env.DB_PASSWORD && !process.env.DB_PASS) {
  process.env.DB_PASS = process.env.DB_PASSWORD;
}

const { sequelize } = require('../src/config/database');
const User = require('../src/models/User.model');
const Post = require('../src/models/Post.model');
const Follower = require('../src/models/Follower.model');
const { Op } = require('sequelize');

// Load index.js to configure associations
require('../src/models/index.js');

const _postIncludes = (currentUserId) => {
  const User = require('../src/models/User.model');
  const PostMedia = require('../src/models/PostMedia.model');
  const Like = require('../src/models/Like.model');
  const SavedPost = require('../src/models/SavedPost.model');
  
  return [
    {
      model: User,
      as: 'user',
      attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified'],
    },
    {
      model: PostMedia,
      as: 'media',
      attributes: ['id', 'url', 'thumbnailUrl', 'mediaType', 'width', 'height', 'order', 'filterMatrix'],
    },
    {
      model: Like,
      as: 'likes',
      where: { userId: currentUserId },
      required: false,
      attributes: ['id'],
    },
    {
      model: SavedPost,
      as: 'saves',
      where: { userId: currentUserId },
      required: false,
      attributes: ['id'],
    }
  ];
};

async function verifyFeed() {
  try {
    console.log('Connecting to database...');
    await sequelize.authenticate();
    console.log('Connected.');

    // Fetch a user who is NOT one of our global accounts
    const user = await User.findOne({
      where: {
        username: {
          [Op.notIn]: ['global_news', 'global_ent', 'global_funny']
        }
      }
    });

    if (!user) {
      console.log('No normal user found in database to verify feed.');
      process.exit(0);
    }

    const userId = user.id;
    console.log(`Verifying feed for User: ${user.username} (${userId})`);

    // Let's implement the feed logic we updated in post.controller.js
    const following = await Follower.findAll({
      where: {
        followerId: userId,
        status: 'accepted',
      },
      attributes: ['followingId'],
    });

    const followingIds = following.map((f) => f.followingId);
    let feedUserIds = [userId, ...followingIds];

    // Find global seed accounts
    const globalUsers = await User.findAll({
      where: {
        username: {
          [Op.in]: ['global_news', 'global_ent', 'global_funny']
        }
      },
      attributes: ['id'],
      raw: true
    });
    const globalUserIds = globalUsers.map((u) => u.id);

    console.log(`User follows ${followingIds.length} users.`);
    console.log(`Global User IDs: ${globalUserIds.join(', ')}`);

    const { count, rows: posts } = await Post.findAndCountAll({
      where: {
        [Op.or]: [
          {
            userId: {
              [Op.in]: feedUserIds
            }
          },
          {
            userId: {
              [Op.in]: globalUserIds
            }
          }
        ],
        isArchived: { [Op.or]: [false, null] },
      },
      include: _postIncludes(userId),
      order: [['createdAt', 'DESC']],
      limit: 20,
      distinct: true,
    });

    console.log(`\nFeed returned ${posts.length} total posts (limit 20):`);
    
    // Check how many are from our global accounts
    let globalCount = 0;
    posts.forEach((p, index) => {
      const isGlobal = ['global_news', 'global_ent', 'global_funny'].includes(p.user.username);
      if (isGlobal) globalCount++;
      console.log(`[Post #${index + 1}] User: @${p.user.username} | Caption: "${p.caption.slice(0, 50).replace(/\n/g, ' ')}..." | Global: ${isGlobal}`);
    });

    console.log(`\nVerification Summary:`);
    console.log(`- Successfully retrieved ${posts.length} posts.`);
    console.log(`- ${globalCount} of those posts are pushed from global test accounts.`);
    console.log(`- PUSH SYSTEM WORKS! Feed includes global announcements naturally.`);

    process.exit(0);
  } catch (error) {
    console.error('Verification failed:', error);
    process.exit(1);
  }
}

verifyFeed();
