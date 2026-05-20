// server/src/controllers/user.controller.js

const { User, Follower, Block, Post, sequelize } = require('../models');
const { successResponse, errorResponse } = require('../utils/response.utils');
const {
  uploadProfilePictureToCloudinary,
  deleteFromCloudinary,
} = require('../services/upload.service');
const { Op } = require('sequelize');
const { getBlockedUserIds } = require('../utils/block.utils');

// ─────────────────────────────────────────────────────────────
// HELPER: Format user for public profile response
// ─────────────────────────────────────────────────────────────
const formatPublicProfile = (user, extras = {}) => ({
  id: user.id,
  username: user.username,
  full_name: user.fullName,
  bio: user.bio,
  website: user.website,
  profile_pic_url: user.profile_pic_url,
  is_private: user.is_private,
  is_verified: user.is_verified,
  created_at: user.createdAt,
  // Extra computed fields passed in
  ...extras,
});

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/users/:username
// @desc    Get user profile by username
// @access  Public (but shows less data for private accounts)
// ─────────────────────────────────────────────────────────────
const getUserProfile = async (req, res) => {
  try {
    const { username } = req.params;
    const currentUserId = req.user?.id || null;

    const user = await User.findOne({
      where: {
        username: username.toLowerCase(),
        is_active: true,
        is_banned: false,
      },
    });

    if (!user) {
      return errorResponse(res, 404, 'User not found.');
    }

    if (currentUserId && currentUserId !== user.id) {
      const blockExists = await Block.findOne({
        where: {
          [Op.or]: [
            { blocker_id: currentUserId, blocked_id: user.id },
            { blocker_id: user.id, blocked_id: currentUserId },
          ],
        },
      });

      if (blockExists) {
        return errorResponse(res, 404, 'User not found.');
      }
    }

    const [postCount, followersCount, followingCount] = await Promise.all([
      Post.count({
        where: {
          userId: user.id,
          isArchived: { [Op.or]: [false, null] },
        },
      }),
      Follower.count({
        where: { followingId: user.id, status: 'accepted' },
      }),
      Follower.count({
        where: { followerId: user.id, status: 'accepted' },
      }),
    ]);

    const isOwnProfile = currentUserId === user.id;
    let followStatus = null;
    let isFollowing = false;
    let isFollowedBy = false;

    if (currentUserId && !isOwnProfile) {
      const [myFollow, theirFollow] = await Promise.all([
        Follower.findOne({
          where: {
            followerId: currentUserId,
            followingId: user.id,
          },
        }),
        Follower.findOne({
          where: {
            followerId: user.id,
            followingId: currentUserId,
            status: 'accepted',
          },
        }),
      ]);

      if (myFollow) {
        followStatus =
          myFollow.status === 'accepted' ? 'following' : 'requested';
        isFollowing = myFollow.status === 'accepted';
      } else {
        followStatus = 'not_following';
      }

      isFollowedBy = !!theirFollow;
    }

    const profileData = formatPublicProfile(user, {
      post_count: postCount,
      followers_count: followersCount,
      following_count: followingCount,
      is_own_profile: isOwnProfile,
      follow_status: isOwnProfile ? null : followStatus,
      is_following: isOwnProfile ? null : isFollowing,
      is_followed_by: isOwnProfile ? null : isFollowedBy,
    });

    if (user.is_private && !isOwnProfile && !isFollowing) {
      return successResponse(res, 200, 'User profile fetched', {
        user: {
          ...profileData,
          is_restricted: true,
          message: 'This account is private.',
        },
      });
    }

    return successResponse(res, 200, 'User profile fetched successfully', {
      user: profileData,
    });

  } catch (error) {
    console.error('❌ Get user profile error:', error);
    return errorResponse(res, 500, 'Something went wrong.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   PUT /api/v1/users/profile
// @desc    Update own profile (bio, name, website, gender)
// @access  Private
// ─────────────────────────────────────────────────────────────
const updateProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      full_name,
      username,
      bio,
      website,
      gender,
      is_private,
    } = req.body;

    // 1. GET CURRENT USER
    const user = await User.findByPk(userId);

    if (!user) {
      return errorResponse(res, 404, 'User not found.');
    }

    // 2. IF USERNAME IS BEING CHANGED, CHECK IF AVAILABLE
    if (username && username.toLowerCase() !== user.username) {
      // Validate username format
      if (!/^[a-zA-Z0-9._]+$/.test(username)) {
        return errorResponse(
          res,
          400,
          'Username can only contain letters, numbers, dots and underscores.'
        );
      }

      if (username.length < 3 || username.length > 30) {
        return errorResponse(
          res,
          400,
          'Username must be between 3 and 30 characters.'
        );
      }

      // Check if taken by someone else
      const existingUser = await User.findOne({
        where: {
          username: username.toLowerCase(),
          id: { [Op.ne]: userId }, // Not current user
        },
      });

      if (existingUser) {
        return errorResponse(
          res,
          409,
          'Username is already taken. Please choose a different one.'
        );
      }
    }

    // 3. VALIDATE WEBSITE URL IF PROVIDED
    if (website && website.trim() !== '') {
      const urlPattern = /^(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*\/?$/;
      if (!urlPattern.test(website)) {
        return errorResponse(res, 400, 'Please provide a valid website URL.');
      }
    }

    // 4. BUILD UPDATE OBJECT (only update provided fields)
    const updateData = {};

    if (full_name !== undefined) {
      if (full_name.trim().length < 1) {
        return errorResponse(res, 400, 'Full name cannot be empty.');
      }
      updateData.fullName = full_name.trim();
    }

    if (username !== undefined) {
      updateData.username = username.toLowerCase();
    }

    if (bio !== undefined) {
      if (bio.length > 150) {
        return errorResponse(res, 400, 'Bio cannot exceed 150 characters.');
      }
      updateData.bio = bio;
    }

    if (website !== undefined) {
      updateData.website = website.trim() || null;
    }

    if (gender !== undefined) {
      const validGenders = ['male', 'female', 'custom', 'prefer_not_to_say'];
      if (gender && !validGenders.includes(gender)) {
        return errorResponse(res, 400, 'Invalid gender value.');
      }
      updateData.gender = gender || null;
    }

    if (is_private !== undefined) {
      updateData.is_private = Boolean(is_private);
    }

    // 5. IF NOTHING TO UPDATE
    if (Object.keys(updateData).length === 0) {
      return errorResponse(res, 400, 'No fields provided to update.');
    }

    // 6. UPDATE IN DATABASE
    await user.update(updateData);

    // 7. FETCH UPDATED USER
    const updatedUser = await User.findByPk(userId);

    console.log(`✅ Profile updated for user: ${userId}`);

    return successResponse(res, 200, 'Profile updated successfully!', {
      user: {
        id: updatedUser.id,
        username: updatedUser.username,
        email: updatedUser.email,
        full_name: updatedUser.fullName,
        bio: updatedUser.bio,
        website: updatedUser.website,
        profile_pic_url: updatedUser.profile_pic_url,
        gender: updatedUser.gender,
        is_private: updatedUser.is_private,
        is_verified: updatedUser.is_verified,
        updated_at: updatedUser.updatedAt,
      },
    });

  } catch (error) {
    console.error('❌ Update profile error:', error);

    if (error.name === 'SequelizeUniqueConstraintError') {
      return errorResponse(res, 409, 'Username is already taken.');
    }

    return errorResponse(res, 500, 'Something went wrong.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   PUT /api/v1/users/profile-picture
// @desc    Upload/change profile picture
// @access  Private
// ─────────────────────────────────────────────────────────────
const updateProfilePicture = async (req, res) => {
  try {
    const userId = req.user.id;

    // 1. CHECK IF FILE WAS UPLOADED
    // req.file is set by multer middleware
    if (!req.file) {
      return errorResponse(
        res,
        400,
        'Please provide an image file.'
      );
    }

    console.log(`📸 Uploading profile picture for user: ${userId}`);
    console.log(`   File: ${req.file.originalname} (${req.file.size} bytes)`);

    // 2. GET CURRENT USER
    const user = await User.findByPk(userId);

    // 3. DELETE OLD PROFILE PICTURE FROM CLOUDINARY
    // If they had a previous picture, remove it
    if (user.profile_pic_url) {
      // Extract public_id from old URL
      // Cloudinary URL format: https://res.cloudinary.com/cloud/image/upload/v123/instagram-clone/profile-pictures/profile_userId.jpg
      const oldPublicId = `instagram-clone/profile-pictures/profile_${userId}`;
      await deleteFromCloudinary(oldPublicId);
      console.log('🗑️  Old profile picture deleted from Cloudinary');
    }

    // 4. UPLOAD NEW PICTURE TO CLOUDINARY
    const uploadResult = await uploadProfilePictureToCloudinary(
      req.file.buffer,
      req.file.mimetype
    );

    console.log('✅ Profile picture uploaded to Cloudinary:', uploadResult.url);

    // 5. SAVE URL TO DATABASE
    await user.update({
      profile_pic_url: uploadResult.url,
    });

    return successResponse(
      res,
      200,
      'Profile picture updated successfully! 📸',
      {
        profile_pic_url: uploadResult.url,
      }
    );

  } catch (error) {
    console.error('❌ Update profile picture error:', error);
    return errorResponse(
      res,
      500,
      'Failed to upload profile picture. Please try again.'
    );
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/users/profile-picture
// @desc    Remove profile picture (set to default)
// @access  Private
// ─────────────────────────────────────────────────────────────
const removeProfilePicture = async (req, res) => {
  try {
    const userId = req.user.id;
    const user = await User.findByPk(userId);

    // If no profile picture, nothing to do
    if (!user.profile_pic_url) {
      return errorResponse(
        res,
        400,
        'You do not have a profile picture to remove.'
      );
    }

    // Delete from Cloudinary
    const oldPublicId = `instagram-clone/profile-pictures/profile_${userId}`;
    await deleteFromCloudinary(oldPublicId);

    // Set to null in database
    await user.update({ profile_pic_url: null });

    console.log(`🗑️  Profile picture removed for user: ${userId}`);

    return successResponse(
      res,
      200,
      'Profile picture removed successfully.',
      { profile_pic_url: null }
    );

  } catch (error) {
    console.error('❌ Remove profile picture error:', error);
    return errorResponse(res, 500, 'Something went wrong.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/users/search?q=john&page=1&limit=20
// @desc    Search users by username or full name
// @access  Private
// ─────────────────────────────────────────────────────────────
const searchUsers = async (req, res) => {
  try {
    const currentUserId = req.user.id;
    const {
      q,             // Search query
      page = 1,
      limit = 20,
    } = req.query;

    // 1. VALIDATE QUERY
    if (!q || q.trim().length === 0) {
      return errorResponse(res, 400, 'Search query is required.');
    }

    if (q.trim().length < 1) {
      return errorResponse(
        res,
        400,
        'Search query must be at least 1 character.'
      );
    }

    const searchTerm = q.trim().toLowerCase();
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const blockedUserIds = await getBlockedUserIds(currentUserId);

    // 2. SEARCH USERS
    // Search in username AND full name
    // Use parameterized query to prevent SQL injection
    const exactMatch = searchTerm;
    const startsWithMatch = searchTerm + '%';

    const { count, rows: users } = await User.findAndCountAll({
      where: {
        [Op.and]: [
          // Not the current user
          { id: { [Op.ne]: currentUserId } },
          // Not a blocked user
          { id: { [Op.notIn]: blockedUserIds } },
          // Active and not banned
          { is_active: true },
          { is_banned: false },
          // Search term matches username or full name
          {
            [Op.or]: [
              {
                username: {
                  [Op.iLike]: `%${searchTerm}%`, // case-insensitive
                },
              },
              {
                fullName: {
                  [Op.iLike]: `%${searchTerm}%`,
                },
              },
            ],
          },
        ],
      },
      attributes: [
        'id',
        'username',
        'fullName',
        'profile_pic_url',
        'bio',
        'is_verified',
        'is_private',
      ],
      // Exact matches first, then partial - using safe parameterized approach
      order: [
        [
          User.sequelize.literal(
            'CASE WHEN username = :exactMatch THEN 0 WHEN username LIKE :startsWithMatch THEN 1 ELSE 2 END'
          ),
          'ASC',
        ],
        ['username', 'ASC'],
      ],
      replacements: {
        exactMatch: exactMatch,
        startsWithMatch: startsWithMatch,
      },
      limit: parseInt(limit),
      offset,
    });

    // 3. CHECK FOLLOW STATUS
    const userIds = users.map(u => u.id);
    
    const follows = await Follower.findAll({
      where: {
        followerId: currentUserId,
        followingId: { [Op.in]: userIds },
        status: 'accepted'
      },
      attributes: ['followingId'],
      raw: true
    });

    const followSet = new Set(follows.map(f => f.followingId));

    // 4. FORMAT RESULTS
    const formattedUsers = users.map((user) => ({
      id: user.id,
      username: user.username,
      full_name: user.fullName,
      profile_pic_url: user.profile_pic_url,
      bio: user.bio,
      is_verified: user.is_verified,
      is_private: user.is_private,
      is_following: followSet.has(user.id),
    }));

    return successResponse(res, 200, 'Search results', {
      users: formattedUsers,
      pagination: {
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        total_pages: Math.ceil(count / parseInt(limit)),
        has_next: offset + users.length < count,
      },
      query: searchTerm,
    });

  } catch (error) {
    console.error('❌ Search users error:', error);
    return errorResponse(res, 500, 'Something went wrong.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/users/suggestions?limit=10
// @desc    Get suggested users to follow
// @access  Private
// ─────────────────────────────────────────────────────────────
const getSuggestedUsers = async (req, res) => {
  try {
    const currentUserId = req.user.id;
    const limit = parseInt(req.query.limit) || 10;

    const alreadyFollowing = await Follower.findAll({
      where: { followerId: currentUserId },
      attributes: ['followingId'],
      raw: true,
    });

    const blockedUserIds = await getBlockedUserIds(currentUserId);

    const excludeIds = [
      currentUserId,
      ...alreadyFollowing.map((follow) => follow.followingId),
      ...blockedUserIds,
    ];

    const users = await User.findAll({
      where: {
        id: { [Op.notIn]: excludeIds },
        is_active: true,
        is_banned: false,
      },
      attributes: [
        'id',
        'username',
        'fullName',
        'profile_pic_url',
        'is_verified',
        'is_private',
        'bio',
      ],
      order: sequelize.random(),
      limit,
    });

    const formattedUsers = users.map((user) => ({
      id: user.id,
      username: user.username,
      full_name: user.fullName,
      profile_pic_url: user.profile_pic_url,
      is_verified: user.is_verified,
      is_private: user.is_private,
      bio: user.bio,
      is_following: false,
      mutual_followers_count: 0,
    }));

    return successResponse(
      res,
      200,
      'Suggested users fetched',
      { users: formattedUsers }
    );

  } catch (error) {
    console.error('❌ Get suggestions error:', error);
    return errorResponse(res, 500, 'Something went wrong.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/users/:id/basic
// @desc    Get basic user info by ID (for internal use)
// @access  Private
// ─────────────────────────────────────────────────────────────
const getUserById = async (req, res) => {
  try {
    const { id } = req.params;

    const user = await User.findOne({
      where: {
        id,
        is_active: true,
        is_banned: false,
      },
      attributes: [
        'id',
        'username',
        'fullName',
        'profile_pic_url',
        'is_verified',
        'is_private',
      ],
    });

    if (!user) {
      return errorResponse(res, 404, 'User not found.');
    }

    const currentUserId = req.user?.id;
    if (currentUserId && currentUserId !== user.id) {
      const blockExists = await Block.findOne({
        where: {
          [Op.or]: [
            { blocker_id: currentUserId, blocked_id: user.id },
            { blocker_id: user.id, blocked_id: currentUserId },
          ],
        },
      });

      if (blockExists) {
        return errorResponse(res, 404, 'User not found.');
      }
    }

    return successResponse(res, 200, 'User found', { user });

  } catch (error) {
    console.error('❌ Get user by ID error:', error);
    return errorResponse(res, 500, 'Something went wrong.');
  }
};

// ─────────────────────────────────────────────────────
// SAVE FCM TOKEN
// PUT /api/users/fcm-token
// body: { fcmToken: string }
// Called by Flutter app on login + app open
// ─────────────────────────────────────────────────────
const saveFcmToken = async (req, res) => {
  try {
    const userId = req.user.id;
    const { fcmToken } = req.body;

    if (!fcmToken || typeof fcmToken !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'fcmToken is required',
        timestamp: new Date().toISOString(),
      });
    }

    // ─── Validate token format (basic check) ──────────
    if (fcmToken.length < 20) {
      return res.status(400).json({
        success: false,
        message: 'Invalid FCM token format',
        timestamp: new Date().toISOString(),
      });
    }

    // ─── Update user's FCM token ───────────────────────
    await User.update(
      { fcmToken },
      { where: { id: userId } }
    );

    console.log(`📱 FCM token saved for user ${userId}`);

    return res.json({
      success: true,
      message: 'FCM token saved',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('❌ saveFcmToken error:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Failed to save FCM token',
      timestamp: new Date().toISOString(),
    });
  }
};

// ─────────────────────────────────────────────────────
// CLEAR FCM TOKEN (on logout)
// DELETE /api/users/fcm-token
// ─────────────────────────────────────────────────────
const clearFcmToken = async (req, res) => {
  try {
    const userId = req.user.id;

    await User.update(
      { fcmToken: null },
      { where: { id: userId } }
    );

    console.log(`📱 FCM token cleared for user ${userId}`);

    return res.json({
      success: true,
      message: 'FCM token cleared',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('❌ clearFcmToken error:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Failed to clear FCM token',
      timestamp: new Date().toISOString(),
    });
  }
};

module.exports = {
  getUserProfile,
  updateProfile,
  updateProfilePicture,
  removeProfilePicture,
  searchUsers,
  getSuggestedUsers,
  getUserById,
  saveFcmToken,
  clearFcmToken,
};
