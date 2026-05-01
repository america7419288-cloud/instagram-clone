// server/src/routes/follow.routes.js

const express = require('express');
const router = express.Router();

const {
  followUser,
  unfollowUser,
  acceptFollowRequest,
  rejectFollowRequest,
  cancelFollowRequest,
  getFollowers,
  getFollowing,
  getFollowStatus,
  getFollowRequests,
  removeFollower,
  blockUser,
  unblockUser,
} = require('../controllers/follow.controller');

const { protect } = require('../middleware/auth.middleware');

// ─── ROUTES ────────────────────────────────────────────────
// ⚠️ ORDER MATTERS - specific before params

// Pending follow requests (inbox) - BEFORE /:id routes
router.get('/follow-requests', protect, getFollowRequests);

// Follow / Unfollow
router.post('/:id/follow', protect, followUser);
router.delete('/:id/follow', protect, unfollowUser);

// Follow request management
router.post('/:id/follow/accept', protect, acceptFollowRequest);
router.post('/:id/follow/reject', protect, rejectFollowRequest);
router.delete('/:id/follow/cancel', protect, cancelFollowRequest);

// Followers / Following lists
router.get('/:id/followers', protect, getFollowers);
router.get('/:id/following', protect, getFollowing);

// Follow status check
router.get('/:id/follow-status', protect, getFollowStatus);

// Remove a follower
router.delete('/:id/follower', protect, removeFollower);

// Block / Unblock
router.post('/:id/block', protect, blockUser);
router.delete('/:id/block', protect, unblockUser);

module.exports = router;