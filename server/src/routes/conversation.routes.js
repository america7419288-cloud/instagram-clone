// server/src/routes/conversation.routes.js

const express = require('express');
const router = express.Router();

const {
  createOrGetConversation,
  getInbox,
  getConversation,
  getMessages,
  sendMessage,
  deleteMessage,
  markAsRead,
  markAsUnread,
  getUnreadCount,
  leaveConversation,
  debugConversation,
  editMessage,
  createGroupConversation,
  setDisappearingMessages,
  searchMessages,
  reactToMessage,
  acceptConversationRequest,
  rejectConversationRequest,
  muteConversation,
  unmuteConversation,
  getMuteStatus,
  getGroupMembers,
  addGroupMembers,
  removeGroupMember,
  updateGroupMemberRole,
  updateGroupMemberNickname,
  muteGroupMember,
  getGroupInviteLink,
  resetGroupInviteLink,
  joinGroupViaInviteLink,
  getPinnedMessages,
  pinGroupMessage,
  unpinGroupMessage,
  updateGroupSettings,
} = require('../controllers/conversation.controller');

const { protect } = require('../middleware/auth.middleware');
const { uploadPostMedia } = require('../services/upload.service');

// ─── ROUTES ────────────────────────────────────────────────
// ⚠️ Specific routes BEFORE param routes

// GET unread count (for badge) - BEFORE /:id
router.get('/unread-count', protect, getUnreadCount);

// DEBUG endpoint - check conversation and participant status
router.get('/:id/debug', protect, debugConversation);

// GET inbox (all conversations)
router.get('/', protect, getInbox);

// POST create or get DM conversation
router.post('/', protect, createOrGetConversation);

// POST create group conversation (MUST be registered before dynamic /:id to prevent param collision)
router.post('/group', protect, createGroupConversation);

// POST join group via invite link (BEFORE /:id parameter)
router.post('/join/:inviteCode', protect, joinGroupViaInviteLink);

// GET single conversation
router.get('/:id', protect, getConversation);

// DELETE leave/hide/soft-delete conversation
router.delete('/:id', protect, leaveConversation);

// GET messages in conversation
router.get('/:id/messages', protect, getMessages);

// GET search history of messages in conversation
router.get('/:id/search', protect, searchMessages);

// POST send message — support optional media file upload
router.post('/:id/messages', protect, uploadPostMedia.single('media'), sendMessage);

// PUT edit message content
router.put('/:id/messages/:messageId', protect, editMessage);

// DELETE unsend a message (conversation-scoped URL used by the client)
router.delete('/:id/messages/:messageId', protect, deleteMessage);

// PUT mark as read
router.put('/:id/read', protect, markAsRead);

// PUT mark as unread
router.put('/:id/unread', protect, markAsUnread);

// POST mute conversation
router.post('/:id/mute', protect, muteConversation);

// DELETE unmute conversation
router.delete('/:id/mute', protect, unmuteConversation);

// GET mute status of conversation
router.get('/:id/mute-status', protect, getMuteStatus);

// PUT disappearing messages duration
router.put('/:id/disappearing', protect, setDisappearingMessages);

// POST react to a message with an emoji (toggles on/off)
router.post('/:id/messages/:messageId/react', protect, reactToMessage);

// POST accept conversation request
router.post('/:id/accept', protect, acceptConversationRequest);

// POST reject conversation request
router.post('/:id/reject', protect, rejectConversationRequest);

// ─── ADVANCED GROUP ROUTES ──────────────────────────────────
// GET group members list
router.get('/:id/members', protect, getGroupMembers);

// POST add group members
router.post('/:id/members', protect, addGroupMembers);

// DELETE remove group member
router.delete('/:id/members/:userId', protect, removeGroupMember);

// PUT update group member role (admin/member)
router.put('/:id/members/:userId/role', protect, updateGroupMemberRole);

// PUT update group member nickname
router.put('/:id/members/:userId/nickname', protect, updateGroupMemberNickname);

// POST mute group member (notifications toggle)
router.post('/:id/members/:userId/mute', protect, muteGroupMember);

// GET group invite link
router.get('/:id/invite-link', protect, getGroupInviteLink);

// POST reset group invite link
router.post('/:id/invite-link/reset', protect, resetGroupInviteLink);

// GET pinned group messages
router.get('/:id/pinned', protect, getPinnedMessages);

// POST pin message in group
router.post('/:id/messages/:messageId/pin', protect, pinGroupMessage);

// DELETE unpin message in group
router.delete('/:id/messages/:messageId/pin', protect, unpinGroupMessage);

// PUT update group settings
router.put('/:id/settings', protect, updateGroupSettings);

module.exports = router;