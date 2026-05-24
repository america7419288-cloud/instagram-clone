const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth.middleware');
const ctrl = require('../controllers/settings.controller');
const savedCtrl = require('../controllers/saved.controller');
const archiveCtrl = require('../controllers/archive.controller');
const closeFriendCtrl = require('../controllers/closefriend.controller');
const mutedCtrl = require('../controllers/muted.controller');
const blockedCtrl = require('../controllers/blocked.controller');

// ── SETTINGS (GET ALL / UPDATE SECTION) ──
router.get('/', protect, ctrl.getAllSettings);
router.put('/privacy', protect, ctrl.updatePrivacy);
router.put('/comments', protect, ctrl.updateComments);
router.put('/likes-shares', protect, ctrl.updateLikesShares);
router.put('/notifications', protect, ctrl.updateNotifications);
router.put('/timestamp', protect, ctrl.updateTimestamp);
router.put('/archive-settings', protect, ctrl.updateArchiveSettings);
router.put('/saved-settings', protect, ctrl.updateSavedSettings);

// ── SAVED POSTS ───────────────────────────
router.get('/saved', protect, savedCtrl.getSavedPosts);
router.post('/saved/:postId', protect, savedCtrl.savePost);
router.delete('/saved/:postId', protect, savedCtrl.unsavePost);
router.get('/saved/collections', protect, savedCtrl.getCollections);
router.post('/saved/collections', protect, savedCtrl.createCollection);
router.put('/saved/collections/:id', protect, savedCtrl.updateCollection);
router.delete('/saved/collections/:id', protect, savedCtrl.deleteCollection);
router.post(
  '/saved/collections/:id/posts/:postId',
  protect,
  savedCtrl.addToCollection,
);
router.delete(
  '/saved/collections/:id/posts/:postId',
  protect,
  savedCtrl.removeFromCollection,
);

// ── CLOSE FRIENDS ─────────────────────────
router.get('/close-friends', protect, closeFriendCtrl.getCloseFriends);
router.post('/close-friends/:userId', protect, closeFriendCtrl.addCloseFriend);
router.delete('/close-friends/:userId', protect, closeFriendCtrl.removeCloseFriend);
router.get('/close-friends/check/:userId', protect, closeFriendCtrl.isCloseFriend);

// ── MUTED ACCOUNTS ────────────────────────
router.get('/muted', protect, mutedCtrl.getMutedAccounts);
router.post('/muted/:userId', protect, mutedCtrl.muteAccount);
router.put('/muted/:userId', protect, mutedCtrl.updateMuteSettings);
router.delete('/muted/:userId', protect, mutedCtrl.unmuteAccount);

// ── BLOCKED ACCOUNTS ──────────────────────
router.get('/blocked', protect, blockedCtrl.getBlockedAccounts);
router.post('/blocked/:userId', protect, blockedCtrl.blockAccount);
router.delete('/blocked/:userId', protect, blockedCtrl.unblockAccount);
router.get('/blocked/check/:userId', protect, blockedCtrl.isBlocked);

// ── ARCHIVE ───────────────────────────────
router.get('/archive', protect, archiveCtrl.getArchive);
router.get('/archive/stories', protect, archiveCtrl.getArchivedStories);
router.get('/archive/posts', protect, archiveCtrl.getArchivedPosts);
router.post('/archive/:type/:contentId', protect, archiveCtrl.archiveContent);
router.delete('/archive/:type/:contentId', protect, archiveCtrl.unarchiveContent);
router.delete('/archive', protect, archiveCtrl.clearArchive);

module.exports = router;
