// server/src/controllers/follow.controller.js

const { Follower, User, Post, PostMedia, sequelize } = require('../models');
const {
  successResponse,
  errorResponse,
  paginatedResponse,
} = require('../utils/response.utils');
const {
  notifyFollow,
  notifyFollowRequest,
  notifyFollowAccepted,
} = require('../services/notification.service');
const { Op } = require('sequelize');

// ─── HELPER: Format user for follow lists ──────────────────
const formatFollowUser = (user, extras = {}) => ({
  id: user.id,
  username: user.username,
  full_name: user.full_name,
  profile_pic_url: user.profile_pic_url,
  is_verified: user.is_verified,
  is_private: user.is_private,
  bio: user.bio,
  ...extras,
});

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/users/:id/follow
// @desc    Follow a user
// @access  Private
// ─────────────────────────────────────────────────────────────
const followUser = async (req, res) => {
  try {
    const followingId = req.params.id; // User to follow
    const followerId = req.user.id;   // Current user

    // 1. CANNOT FOLLOW YOURSELF
    if (followerId === followingId) {
      return errorResponse(res, 400, 'You cannot follow yourself.');
    }

    // 2. CHECK TARGET USER EXISTS
    const targetUser = await User.findOne({
      where: {
        id: followingId,
        is_active: true,
        is_banned: false,
      },
    });

    if (!targetUser) {
      return errorResponse(res, 404, 'User not found.');
    }

    // 3. CHECK IF ALREADY FOLLOWING
    const existingFollow = await Follower.findOne({
      where: { followerId: followerId, followingId: followingId },
    });

    if (existingFollow) {
      if (existingFollow.status === 'accepted') {
        return errorResponse(res, 400, 'You are already following this user.');
      }
      if (existingFollow.status === 'pending') {
        return errorResponse(
          res, 400,
          'Follow request already sent. Waiting for approval.'
        );
      }
      // If rejected → allow re-follow
      await existingFollow.destroy();
    }

    // 4. DETERMINE STATUS BASED ON ACCOUNT TYPE
    // Private account → request must be approved
    // Public account  → auto-accept
    const status = targetUser.is_private ? 'pending' : 'accepted';

    // 5. CREATE FOLLOW RECORD
    const follow = await Follower.create({
      followerId: followerId,
      followingId: followingId,
      status,
    });

    if (status === 'accepted') {
      notifyFollow(followerId, followingId);
    } else {
      notifyFollowRequest(followerId, followingId);
    }

    console.log(
      `👥 Follow: ${followerId} → ${followingId} (${status})`
    );

    // 6. GET UPDATED COUNTS
    const followersCount = await Follower.count({
      where: { followingId: followingId, status: 'accepted' },
    });

    if (status === 'pending') {
      return successResponse(res, 200, 'Follow request sent! ⏳', {
        follow_status: 'pending',
        message: `Follow request sent to @${targetUser.username}`,
        followers_count: followersCount,
      });
    }

    return successResponse(
      res, 200,
      `You are now following @${targetUser.username}! 🎉`,
      {
        follow_status: 'accepted',
        followers_count: followersCount,
      }
    );

  } catch (error) {
    console.error('❌ Follow user error:', error);
    return errorResponse(res, 500, 'Failed to follow user.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/users/:id/follow
// @desc    Unfollow a user (or cancel follow request)
// @access  Private
// ─────────────────────────────────────────────────────────────
const unfollowUser = async (req, res) => {
  try {
    const followingId = req.params.id;
    const followerId = req.user.id;

    const follow = await Follower.findOne({
      where: { followerId: followerId, followingId: followingId },
    });

    if (!follow) {
      return errorResponse(res, 400, 'You are not following this user.');
    }

    const targetUser = await User.findByPk(followingId);
    const wasPending = follow.status === 'pending';

    await follow.destroy();

    const followersCount = await Follower.count({
      where: { followingId: followingId, status: 'accepted' },
    });

    console.log(`👥 Unfollowed: ${followerId} → ${followingId}`);

    return successResponse(
      res, 200,
      wasPending
        ? 'Follow request cancelled.'
        : `Unfollowed @${targetUser?.username || 'user'}.`,
      {
        follow_status: 'not_following',
        followers_count: followersCount,
      }
    );

  } catch (error) {
    console.error('❌ Unfollow error:', error);
    return errorResponse(res, 500, 'Failed to unfollow user.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/users/:id/follow-status
// @desc    Check follow relationship between current user and target
// @access  Private
// ─────────────────────────────────────────────────────────────
const getFollowStatus = async (req, res) => {
  try {
    const targetId = req.params.id;
    const currentUserId = req.user.id;

    // Check if current user follows target
    const follow = await Follower.findOne({
      where: {
        followerId: currentUserId,
        followingId: targetId,
      },
    });

    // Check if target follows current user back
    const followBack = await Follower.findOne({
      where: {
        followerId: targetId,
        followingId: currentUserId,
        status: 'accepted',
      },
    });

    let followStatus = 'not_following';
    if (follow) {
      followStatus = follow.status; // 'pending' or 'accepted'
    }

    // Get counts
    const followersCount = await Follower.count({
      where: { followingId: targetId, status: 'accepted' },
    });

    const followingCount = await Follower.count({
      where: { followerId: targetId, status: 'accepted' },
    });

    return successResponse(res, 200, 'Follow status fetched', {
      target_user_id: targetId,
      follow_status: followStatus,
      is_following: followStatus === 'accepted',
      is_follow_requested: followStatus === 'pending',
      follows_you: !!followBack,
      followers_count: followersCount,
      following_count: followingCount,
    });

  } catch (error) {
    console.error('❌ Get follow status error:', error);
    return errorResponse(res, 500, 'Failed to get follow status.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/users/:id/followers
// @desc    Get followers list for a user
// @access  Private
// ─────────────────────────────────────────────────────────────
const getFollowers = async (req, res) => {
  try {
    const { id: userId } = req.params;
    const currentUserId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const search = req.query.q || '';

    // Build where clause for search
    const userWhere = {
      is_active: true,
      is_banned: false,
    };

    if (search) {
      userWhere[Op.or] = [
        { username: { [Op.iLike]: `%${search}%` } },
        { full_name: { [Op.iLike]: `%${search}%` } },
      ];
    }

    const { count, rows: followers } = await Follower.findAndCountAll({
      where: { followingId: userId, status: 'accepted' },
      include: [
        {
          model: User,
          as: 'followerUser',
          where: userWhere,
          attributes: [
            'id', 'username', 'full_name',
            'profile_pic_url', 'is_verified', 'is_private', 'bio',
          ],
        },
      ],
      order: [['created_at', 'DESC']],
      limit,
      offset,
    });

    // Get current user's follow status for each follower
    const followerUserIds = followers.map((f) => f.followerUser.id);

    const currentUserFollows = await Follower.findAll({
      where: {
        followerId: currentUserId,
        followingId: { [Op.in]: followerUserIds },
        status: 'accepted',
      },
      attributes: ['following_id'],
      raw: true,
    });

    const followingSet = new Set(
      currentUserFollows.map((f) => f.followingId)
    );

    const formattedFollowers = followers.map((f) => ({
      ...formatFollowUser(f.followerUser, {
        is_following: followingSet.has(f.followerUser.id),
        followed_at: f.createdAt,
      }),
    }));

    return paginatedResponse(
      res,
      'Followers fetched',
      formattedFollowers,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get followers error:', error);
    return errorResponse(res, 500, 'Failed to fetch followers.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/users/:id/following
// @desc    Get following list for a user
// @access  Private
// ─────────────────────────────────────────────────────────────
const getFollowing = async (req, res) => {
  try {
    const { id: userId } = req.params;
    const currentUserId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const search = req.query.q || '';

    const userWhere = {
      is_active: true,
      is_banned: false,
    };

    if (search) {
      userWhere[Op.or] = [
        { username: { [Op.iLike]: `%${search}%` } },
        { full_name: { [Op.iLike]: `%${search}%` } },
      ];
    }

    const { count, rows: following } = await Follower.findAndCountAll({
      where: { followerId: userId, status: 'accepted' },
      include: [
        {
          model: User,
          as: 'followingUser',
          where: userWhere,
          attributes: [
            'id', 'username', 'full_name',
            'profile_pic_url', 'is_verified', 'is_private', 'bio',
          ],
        },
      ],
      order: [['created_at', 'DESC']],
      limit,
      offset,
    });

    // Check which ones current user also follows
    const followingUserIds = following.map((f) => f.followingUser.id);

    const currentUserFollows = await Follower.findAll({
      where: {
        followerId: currentUserId,
        followingId: { [Op.in]: followingUserIds },
        status: 'accepted',
      },
      attributes: ['following_id'],
      raw: true,
    });

    const followingSet = new Set(
      currentUserFollows.map((f) => f.followingId)
    );

    const formattedFollowing = following.map((f) => ({
      ...formatFollowUser(f.followingUser, {
        is_following: followingSet.has(f.followingUser.id),
        followed_at: f.createdAt,
      }),
    }));

    return paginatedResponse(
      res,
      'Following fetched',
      formattedFollowing,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get following error:', error);
    return errorResponse(res, 500, 'Failed to fetch following.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/users/:id/follower
// @desc    Remove a follower (they follow you, you remove them)
// @access  Private
// ─────────────────────────────────────────────────────────────
const removeFollower = async (req, res) => {
  try {
    const followerToRemoveId = req.params.id;
    const currentUserId = req.user.id;

    const follow = await Follower.findOne({
      where: {
        followerId: followerToRemoveId,
        followingId: currentUserId,
        status: 'accepted',
      },
    });

    if (!follow) {
      return errorResponse(res, 400, 'This user is not following you.');
    }

    await follow.destroy();

    console.log(
      `👥 Removed follower: ${followerToRemoveId} from ${currentUserId}`
    );

    return successResponse(
      res, 200,
      'Follower removed successfully.',
      { removed_followerId: followerToRemoveId }
    );

  } catch (error) {
    console.error('❌ Remove follower error:', error);
    return errorResponse(res, 500, 'Failed to remove follower.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/users/follow-requests
// @desc    Get pending follow requests (for private accounts)
// @access  Private
// ─────────────────────────────────────────────────────────────
const getFollowRequests = async (req, res) => {
  try {
    const currentUserId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const { count, rows: requests } = await Follower.findAndCountAll({
      where: {
        followingId: currentUserId,
        status: 'pending',
      },
      include: [
        {
          model: User,
          as: 'followerUser',
          attributes: [
            'id', 'username', 'full_name',
            'profile_pic_url', 'is_verified',
          ],
        },
      ],
      order: [['created_at', 'DESC']],
      limit,
      offset,
    });

    const formattedRequests = requests.map((req) => ({
      request_id: req.id,
      user: formatFollowUser(req.followerUser, {}),
      requested_at: req.createdAt,
    }));

    return paginatedResponse(
      res,
      'Follow requests fetched',
      formattedRequests,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get follow requests error:', error);
    return errorResponse(res, 500, 'Failed to fetch follow requests.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/users/:id/follow/accept
// @desc    Accept a follow request
// @access  Private
// ─────────────────────────────────────────────────────────────
const acceptFollowRequest = async (req, res) => {
  try {
    const requesterId = req.params.id; // Who sent the request
    const currentUserId = req.user.id; // Who is accepting

    const follow = await Follower.findOne({
      where: {
        followerId: requesterId,
        followingId: currentUserId,
        status: 'pending',
      },
    });

    if (!follow) {
      return errorResponse(
        res, 404,
        'Follow request not found.'
      );
    }

    await follow.update({ status: 'accepted' });

    notifyFollowAccepted(currentUserId, requesterId);

    const requester = await User.findByPk(requesterId, {
      attributes: ['id', 'username', 'profile_pic_url'],
    });

    console.log(
      `✅ Follow request accepted: ${requesterId} → ${currentUserId}`
    );

    return successResponse(
      res, 200,
      `You accepted @${requester?.username}'s follow request! ✅`,
      {
        follower: formatFollowUser(requester, {}),
        follow_status: 'accepted',
      }
    );

  } catch (error) {
    console.error('❌ Accept follow request error:', error);
    return errorResponse(res, 500, 'Failed to accept follow request.');
  }
};

const cancelFollowRequest = async (req, res) => {
  // Logic is essentially the same as unfollowUser for a pending state
  return unfollowUser(req, res); 
};

const blockUser = async (req, res) => {
  try {
    // Placeholder for block logic
    return successResponse(res, 200, 'User blocked successfully.');
  } catch (error) {
    return errorResponse(res, 500, 'Failed to block user.');
  }
};

const unblockUser = async (req, res) => {
  try {
    // Placeholder for unblock logic
    return successResponse(res, 200, 'User unblocked successfully.');
  } catch (error) {
    return errorResponse(res, 500, 'Failed to unblock user.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/users/:id/follow/reject
// @desc    Reject a follow request
// @access  Private
// ─────────────────────────────────────────────────────────────
const rejectFollowRequest = async (req, res) => {
  try {
    const requesterId = req.params.id;
    const currentUserId = req.user.id;

    const follow = await Follower.findOne({
      where: {
        followerId: requesterId,
        followingId: currentUserId,
        status: 'pending',
      },
    });

    if (!follow) {
      return errorResponse(res, 404, 'Follow request not found.');
    }

    // Delete the request (don't keep rejected records)
    await follow.destroy();

    console.log(
      `❌ Follow request rejected: ${requesterId} → ${currentUserId}`
    );

    return successResponse(
      res, 200,
      'Follow request rejected.',
      { rejected_requester_id: requesterId }
    );

  } catch (error) {
    console.error('❌ Reject follow request error:', error);
    return errorResponse(res, 500, 'Failed to reject follow request.');
  }
};

module.exports = {
  followUser,
  unfollowUser,
  getFollowStatus,
  getFollowers,
  getFollowing,
  removeFollower,
  getFollowRequests,
  acceptFollowRequest,
  rejectFollowRequest,
  blockUser,   // Add this
  unblockUser, // Add this
  cancelFollowRequest, // Added this
  blockUser,          // Added this
  unblockUser,        // Added this
};
