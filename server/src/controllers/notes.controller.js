// server/src/controllers/notes.controller.js

const { Note, User, Follower } = require('../models');
const { successResponse, errorResponse } = require('../utils/response.utils');
const { getBlockedUserIds } = require('../utils/block.utils');
const { Op } = require('sequelize');

// Helper to format database note model to camelCase JSON expected by the Flutter app
const formatNote = (note, currentUserId) => {
  const n = note.toJSON ? note.toJSON() : note;
  const user = n.user || {};
  return {
    id: n.id,
    userId: n.user_id,
    username: user.username || '',
    avatarUrl: user.profile_pic_url || '',
    text: n.text,
    createdAt: n.created_at || n.createdAt,
    audience: n.audience === 'close_friends' ? 1 : 0,
    isOwn: n.user_id === currentUserId,
    replyCount: 0,
  };
};

/**
 * @desc    Create a new note (replaces any existing note)
 * @route   POST /api/v1/notes
 * @access  Private
 */
const createNote = async (req, res) => {
  try {
    const userId = req.user.id;
    const { text, audience = 'followers' } = req.body;

    // 1. VALIDATE TEXT LIMIT
    if (!text || text.trim().length === 0) {
      return errorResponse(res, 400, 'Note text cannot be empty.');
    }
    if (text.length > 60) {
      return errorResponse(res, 400, 'Note cannot exceed 60 characters.');
    }

    // 2. ENFORCE ONE ACTIVE NOTE: Delete any existing notes for this user
    await Note.destroy({
      where: { user_id: userId },
    });

    // 3. CREATE NEW EPHEMERAL NOTE
    const note = await Note.create({
      user_id: userId,
      text: text.trim(),
      audience: audience === 'close_friends' ? 'close_friends' : 'followers',
      expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000), // Expires in 24 hours
    });

    // 4. FETCH FULL DETAILS FOR RESPONSE
    const fullNote = await Note.findOne({
      where: { id: note.id },
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'username', 'profile_pic_url'],
        },
      ],
    });

    return successResponse(
      res,
      201,
      'Note shared successfully',
      formatNote(fullNote, userId)
    );
  } catch (error) {
    console.error('Error creating note:', error);
    return errorResponse(res, 500, error.message || 'Internal server error');
  }
};

/**
 * @desc    Get active notes feed (user + followed users)
 * @route   GET /api/v1/notes/feed
 * @access  Private
 */
const getNotesFeed = async (req, res) => {
  try {
    const currentUserId = req.user.id;
    const now = new Date();

    // 1. GET FOLLOWED USER IDs
    const following = await Follower.findAll({
      where: {
        followerId: currentUserId,
        status: 'accepted',
      },
      attributes: ['followingId'],
      raw: true,
    });
    const followingIds = following.map((f) => f.followingId);

    // 2. FILTER BLOCKED USERS
    const blockedUserIds = await getBlockedUserIds(currentUserId);
    const filteredFollowingIds = followingIds.filter(
      (id) => !blockedUserIds.includes(id)
    );

    // 3. FETCH USER'S OWN NOTE & FOLLOWED USER NOTES
    const activeNotes = await Note.findAll({
      where: {
        user_id: {
          [Op.in]: [currentUserId, ...filteredFollowingIds],
        },
        expires_at: {
          [Op.gt]: now, // Not expired
        },
      },
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'username', 'profile_pic_url'],
        },
      ],
      order: [['created_at', 'DESC']],
    });

    // 4. FORMAT AND SEPARATE
    const formattedNotes = activeNotes.map((note) =>
      formatNote(note, currentUserId)
    );

    return successResponse(res, 200, 'Notes feed retrieved', {
      notes: formattedNotes,
    });
  } catch (error) {
    console.error('Error fetching notes feed:', error);
    return errorResponse(res, 500, error.message || 'Internal server error');
  }
};

/**
 * @desc    Delete the current user's active note
 * @route   DELETE /api/v1/notes
 * @access  Private
 */
const deleteNote = async (req, res) => {
  try {
    const userId = req.user.id;

    await Note.destroy({
      where: { user_id: userId },
    });

    return successResponse(res, 200, 'Note deleted successfully');
  } catch (error) {
    console.error('Error deleting note:', error);
    return errorResponse(res, 500, error.message || 'Internal server error');
  }
};

module.exports = {
  createNote,
  getNotesFeed,
  deleteNote,
};
