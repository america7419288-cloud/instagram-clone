// server/src/routes/community.routes.js

const express = require('express');
const router = express.Router();

const {
  createCommunity,
  discoverCommunities,
  searchCommunities,
  joinCommunity,
  leaveCommunity,
  getCommunity,
  getMyCommunities,
  updateCommunity,
  deleteCommunity,
  updateAvatar,
  updateCover,
  getMembers,
  updateMemberRole,
  banMember,
  unbanMember,
  getJoinRequests,
  approveRequest,
  rejectRequest,
  getChannels,
  createChannel,
  updateChannel,
  deleteChannel,
  getCommunityPosts,
  createPost,
  deletePost,
  likePost,
  pinPost,
  getRules,
  addRule,
  updateRule,
  deleteRule,
  getInviteLink,
  joinViaInviteLink,
  votePoll,
  rsvpEvent,
} = require('../controllers/community.controller');

const { protect } = require('../middleware/auth.middleware');
const { uploadProfilePicture, uploadPostMedia } = require('../services/upload.service');

// ─── ROUTES ────────────────────────────────────────────────
// ⚠️ Static/specific routes MUST be registered BEFORE param routes (/:communityId)

// GET my communities (joined)
router.get('/my', protect, getMyCommunities);

// GET discoverable communities
router.get('/discover', protect, discoverCommunities);

// GET search communities
router.get('/search', protect, searchCommunities);

// POST join community via invite link
router.post('/join/:inviteCode', protect, joinViaInviteLink);

// GET single community details
router.get('/:communityId', protect, getCommunity);

// POST create a community
router.post('/', protect, createCommunity);

// PUT update community details
router.put('/:communityId', protect, updateCommunity);

// DELETE delete community
router.delete('/:communityId', protect, deleteCommunity);

// POST join a community
router.post('/:communityId/join', protect, joinCommunity);

// DELETE leave community
router.delete('/:communityId/leave', protect, leaveCommunity);

// ─── Avatar & Cover Photo Uploads ───
router.put('/:communityId/avatar', protect, uploadProfilePicture.single('avatar'), updateAvatar);
router.put('/:communityId/cover', protect, uploadProfilePicture.single('cover'), updateCover);

// ─── Members & Moderation ───
router.get('/:communityId/members', protect, getMembers);
router.put('/:communityId/members/:userId/role', protect, updateMemberRole);
router.post('/:communityId/members/:userId/ban', protect, banMember);
router.delete('/:communityId/members/:userId/ban', protect, unbanMember);

// ─── Join Requests (Private Communities) ───
router.get('/:communityId/requests', protect, getJoinRequests);
router.post('/:communityId/requests/:userId/approve', protect, approveRequest);
router.post('/:communityId/requests/:userId/reject', protect, rejectRequest);

// ─── Channels ───
router.get('/:communityId/channels', protect, getChannels);
router.post('/:communityId/channels', protect, createChannel);
router.put('/:communityId/channels/:channelId', protect, updateChannel);
router.delete('/:communityId/channels/:channelId', protect, deleteChannel);

// ─── Posts & Feed ───
router.get('/:communityId/posts', protect, getCommunityPosts);
router.post('/:communityId/posts', protect, uploadPostMedia.array('media', 10), createPost);
router.delete('/:communityId/posts/:postId', protect, deletePost);
router.post('/:communityId/posts/:postId/like', protect, likePost);
router.put('/:communityId/posts/:postId/pin', protect, pinPost);
router.post('/:communityId/posts/:postId/poll/vote', protect, votePoll);
router.post('/:communityId/posts/:postId/event/rsvp', protect, rsvpEvent);

// ─── Rules ───
router.get('/:communityId/rules', protect, getRules);
router.post('/:communityId/rules', protect, addRule);
router.put('/:communityId/rules/:ruleId', protect, updateRule);
router.delete('/:communityId/rules/:ruleId', protect, deleteRule);

// ─── Invite Link ───
router.get('/:communityId/invite', protect, getInviteLink);

module.exports = router;
