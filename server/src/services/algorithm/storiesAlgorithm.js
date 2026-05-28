// server/src/services/algorithm/storiesAlgorithm.js

const { Op } = require('sequelize');
const { 
  Story, User, UserInterestProfile, CloseFriend, 
  Follower, Message, StoryView 
} = require('../../models');

/**
 * Story ranking algorithm for the active tray
 */
const getRankedStoriesTray = async ({ userId }) => {
  try {
    const now = new Date();

    // ── STEP 1: GET ALL ACTIVE STORIES ────────────
    const activeStories = await Story.findAll({
      where: {
        expires_at: { [Op.gt]: now }
      },
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'username', 'fullName', 'profile_pic_url', 'is_verified']
        }
      ],
      order: [['created_at', 'ASC']] // chronological order inside each author group
    });

    if (activeStories.length === 0) return [];

    // Group stories by author
    const authorStoriesMap = new Map();
    activeStories.forEach(story => {
      const authorId = story.user_id;
      if (!authorStoriesMap.has(authorId)) {
        authorStoriesMap.set(authorId, {
          author: story.user,
          stories: [],
        });
      }
      authorStoriesMap.get(authorId).stories.push(story);
    });

    // ── STEP 2: LOAD RELATIONSHIP METRICS ─────────
    const [closeFriends, following, followers, userProfile] = await Promise.all([
      CloseFriend.findAll({
        where: { userId },
        attributes: ['friendId']
      }),
      Follower.findAll({
        where: { followerId: userId, status: 'accepted' },
        attributes: ['followingId']
      }),
      Follower.findAll({
        where: { followingId: userId, status: 'accepted' },
        attributes: ['followerId']
      }),
      UserInterestProfile.findOne({ where: { userId } }),
    ]);

    const closeFriendIds = new Set(closeFriends.map(f => f.friendId));
    const followingIds = new Set(following.map(f => f.followingId));
    const followerIds = new Set(followers.map(f => f.followerId));

    const authorRelationshipScoreMap = new Map(
      (userProfile?.recentAuthors || [])
        .map(a => [a.authorId, a.score])
    );

    // ── STEP 3: SCORE EACH AUTHOR ─────────────────
    const rankedTray = [];

    for (const [authorId, group] of authorStoriesMap.entries()) {
      let score = 0;

      // 1. Is self? (Self always goes first in the tray)
      const isSelf = authorId === userId;
      if (isSelf) {
        score += 10000; // Put at the absolute front
      }

      // 2. Is close friend? (+50 points)
      const isCloseFriend = closeFriendIds.has(authorId);
      if (isCloseFriend) score += 50;

      // 3. Mutual following check (+30 points)
      const isFollowing = followingIds.has(authorId);
      const isFollower = followerIds.has(authorId);
      if (isFollowing && isFollower) score += 30;
      else if (isFollowing) score += 10;

      // 4. Author relationship interaction boost
      const authorRelationScore = authorRelationshipScoreMap.get(authorId) || 0;
      score += Math.min(40, authorRelationScore * 0.2);

      // 5. Direct Message (DM) activity frequency boost
      // Count messages exchanged in the last 7 days
      const recentMessages = await Message.count({
        where: {
          [Op.or]: [
            { senderId: userId, recipientId: authorId },
            { senderId: authorId, recipientId: userId }
          ],
          createdAt: { [Op.gte]: new Date(Date.now() - 7 * 86400000) }
        }
      });
      score += Math.min(30, recentMessages * 2);

      // 6. View status check (dynamic tray positioning)
      // Check if user has already viewed the latest story of this author
      const latestStory = group.stories[group.stories.length - 1];
      const viewedCount = await StoryView.count({
        where: { viewer_id: userId, story_id: latestStory.id }
      });
      
      const allViewed = viewedCount > 0;

      if (allViewed && !isSelf) {
        // Heavily penalize viewed stories so they move to the back of the tray
        score -= 5000;
      }

      rankedTray.push({
        authorId,
        user: group.author,
        stories: group.stories,
        score,
        allViewed
      });
    }

    // Sort tray: highest score first
    rankedTray.sort((a, b) => b.score - a.score);

    return rankedTray.map(item => ({
      user: item.user,
      stories: item.stories,
      allViewed: item.allViewed
    }));

  } catch (error) {
    console.error('getRankedStoriesTray error:', error.message);
    return [];
  }
};

module.exports = { getRankedStoriesTray };
