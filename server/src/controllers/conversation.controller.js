// server/src/controllers/conversation.controller.js

const {
  Conversation,
  ConversationParticipant,
  Message,
  User,
  Post,
  PostMedia,
  sequelize,
} = require('../models');
const {
  successResponse,
  errorResponse,
  paginatedResponse,
} = require('../utils/response.utils');
const { emitToUser } = require('../services/socket.service');
const { Op } = require('sequelize');

// ─── HELPER: Format conversation for inbox ─────────────────
const formatConversation = (conv, currentUserId) => {
  const c = conv.toJSON ? conv.toJSON() : conv;

  // For DMs, get the other participant's info
  const otherParticipants = (c.participants || []).filter(
    (p) => p.id !== currentUserId
  );

  const otherUser = otherParticipants[0] || null;

  return {
    id: c.id,
    is_group: c.is_group,
    name: c.is_group ? c.name : otherUser?.username,
    avatar_url: c.is_group ? c.avatar_url : otherUser?.profile_pic_url,
    last_message: c.last_message,
    last_message_at: c.last_message_at,
    participants: (c.participants || []).map((p) => ({
      id: p.id,
      username: p.username,
      full_name: p.full_name,
      profile_pic_url: p.profile_pic_url,
      is_verified: p.is_verified,
    })),
    other_user: otherUser
      ? {
          id: otherUser.id,
          username: otherUser.username,
          full_name: otherUser.full_name,
          profile_pic_url: otherUser.profile_pic_url,
          is_verified: otherUser.is_verified,
        }
      : null,
    unread_count: c.unread_count || 0,
    created_at: c.created_at || c.createdAt,
  };
};

// ─── HELPER: Format message ────────────────────────────────
const formatMessage = (message) => {
  const m = message.toJSON ? message.toJSON() : message;

  return {
    id: m.id,
    content: m.is_deleted ? null : m.content,
    media_url: m.is_deleted ? null : m.media_url,
    message_type: m.message_type,
    is_deleted: m.is_deleted,
    deleted_at: m.deleted_at,
    created_at: m.created_at || m.createdAt,
    conversation_id: m.conversation_id,

    // Who sent it
    sender: m.sender
      ? {
          id: m.sender.id,
          username: m.sender.username,
          full_name: m.sender.full_name,
          profile_pic_url: m.sender.profile_pic_url,
        }
      : null,

    // If replying to another message
    replied_to: m.repliedTo
      ? {
          id: m.repliedTo.id,
          content: m.repliedTo.is_deleted
              ? null
              : m.repliedTo.content,
          is_deleted: m.repliedTo.is_deleted,
          sender_id: m.repliedTo.sender_id,
        }
      : null,

    // Shared post info
    shared_post: m.sharedPost
      ? {
          id: m.sharedPost.id,
          thumbnail: m.sharedPost.media?.[0]?.small_url,
        }
      : null,
  };
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/conversations/
// @desc    Create or get existing DM conversation with a user
// @access  Private
// ─────────────────────────────────────────────────────────────
const createOrGetConversation = async (req, res) => {
  try {
    const currentUserId = req.user.id;
    const { user_id: targetUserId } = req.body;

    console.log(`💬 Create/Get DM: ${currentUserId} ↔ ${targetUserId}`);

    // 1. VALIDATE INPUT
    if (!targetUserId) {
      return errorResponse(res, 400, 'Target user ID is required.');
    }

    if (targetUserId === currentUserId) {
      return errorResponse(res, 400, 'Cannot create DM with yourself.');
    }

    // 2. CHECK TARGET USER EXISTS
    const targetUser = await User.findByPk(targetUserId, {
      attributes: ['id', 'username', 'full_name', 'profile_pic_url', 'is_verified'],
    });

    if (!targetUser) {
      return errorResponse(res, 404, 'User not found.');
    }

    // 3. CHECK IF DM ALREADY EXISTS
    // Avoid grouped include aliases here; Postgres can generate fragile aliases
    // for HAVING clauses when Sequelize joins participantRecords.
    const participantMatches = await ConversationParticipant.findAll({
      where: {
        user_id: { [Op.in]: [currentUserId, targetUserId] },
        left_at: null,
      },
      attributes: ['conversation_id', 'user_id'],
      raw: true,
    });

    const participantUserIdsByConversation = new Map();
    participantMatches.forEach((participant) => {
      const conversationUserIds =
        participantUserIdsByConversation.get(participant.conversation_id) ||
        new Set();
      conversationUserIds.add(participant.user_id);
      participantUserIdsByConversation.set(
        participant.conversation_id,
        conversationUserIds
      );
    });

    const existingConversationIds = Array.from(
      participantUserIdsByConversation.entries()
    )
      .filter(([, userIds]) => userIds.size === 2)
      .map(([conversationId]) => conversationId);

    const existingConversation =
      existingConversationIds.length > 0
        ? await Conversation.findOne({
            where: {
              id: { [Op.in]: existingConversationIds },
              is_group: false,
            },
          })
        : null;

    if (existingConversation) {
      console.log(`✅ Found existing DM: ${existingConversation.id}`);
      
      const fullConv = await Conversation.findByPk(existingConversation.id, {
        include: [
          {
            model: User,
            as: 'participants',
            attributes: ['id', 'username', 'full_name', 'profile_pic_url', 'is_verified'],
            through: { attributes: [] },
          },
        ],
      });

      return successResponse(res, 200, 'Conversation already exists', {
        conversation: formatConversation(fullConv, currentUserId),
        is_new: false,
      });
    }

    // 4. CREATE NEW CONVERSATION
    const conversation = await Conversation.create({
      is_group: false,
      created_by: currentUserId,
    });

    // 5. ADD BOTH USERS AS PARTICIPANTS
    await ConversationParticipant.bulkCreate([
      {
        conversation_id: conversation.id,
        user_id: currentUserId,
        role: 'member',
      },
      {
        conversation_id: conversation.id,
        user_id: targetUserId,
        role: 'member',
      },
    ]);

    // 6. GET FULL CONVERSATION
    const fullConversation = await Conversation.findByPk(conversation.id, {
      include: [
        {
          model: User,
          as: 'participants',
          attributes: ['id', 'username', 'full_name', 'profile_pic_url', 'is_verified'],
          through: { attributes: [] },
        },
      ],
    });

    console.log(`✨ Created new DM: ${conversation.id}`);

    return successResponse(res, 201, 'Conversation created successfully', {
      conversation: formatConversation(fullConversation, currentUserId),
      is_new: true,
    });

  } catch (error) {
    console.error('❌ Create conversation error:', error);
    return errorResponse(res, 500, 'Failed to create conversation.', error.message);
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/conversations/
// @desc    Get all conversations for current user (inbox)
// @access  Private
// ─────────────────────────────────────────────────────────────
const getInbox = async (req, res) => {
  try {
    const currentUserId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    console.log(`📬 Fetching inbox for user: ${currentUserId} (Page: ${page}, Limit: ${limit})`);

    // 1. Get all conversations where current user is a participant
    // We use a two-step approach to avoid issues with findAndCountAll + include + limit
    const participantRecords = await ConversationParticipant.findAll({
      where: {
        user_id: currentUserId,
        left_at: null,
      },
      attributes: ['conversation_id'],
    });

    const conversationIds = participantRecords.map(p => p.conversation_id);

    if (conversationIds.length === 0) {
      console.log('📭 User has no conversations.');
      return paginatedResponse(res, 'Inbox is empty', [], {
        page,
        totalPages: 0,
        totalItems: 0,
        limit,
      });
    }

    const { count, rows: conversations } = await Conversation.findAndCountAll({
      where: {
        id: { [Op.in]: conversationIds }
      },
      include: [
        {
          model: User,
          as: 'participants',
          attributes: ['id', 'username', 'full_name', 'profile_pic_url', 'is_verified'],
          through: { attributes: [] },
        },
        {
          model: ConversationParticipant,
          as: 'participantRecords',
          where: { user_id: currentUserId },
          attributes: ['last_read_at', 'is_muted'],
        },
      ],
      order: [
        ['last_message_at', 'DESC'],
        ['updated_at', 'DESC'],
      ],
      limit,
      offset,
      distinct: true,
    });

    console.log(`✅ Found ${conversations.length} conversations for the user.`);

    const unreadCountEntries = await Promise.all(
      conversations.map(async (conv) => {
        const participant = conv.participantRecords?.[0];
        const unreadWhere = {
          conversation_id: conv.id,
          sender_id: { [Op.ne]: currentUserId },
          is_deleted: false,
        };

        if (participant?.last_read_at) {
          unreadWhere.created_at = { [Op.gt]: participant.last_read_at };
        }

        const unreadCount = await Message.count({ where: unreadWhere });
        return [conv.id, unreadCount];
      })
    );

    const unreadCountByConversationId = new Map(unreadCountEntries);

    // 3. Format conversations
    const formattedConversations = conversations.map((conv) => {
      const formatted = formatConversation(conv, currentUserId);
      formatted.unread_count = unreadCountByConversationId.get(conv.id) || 0;
      
      return formatted;
    });

    return paginatedResponse(
      res,
      'Inbox fetched successfully',
      formattedConversations,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get inbox error:', error);
    return errorResponse(res, 500, 'Failed to fetch inbox.', error.message);
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/conversations/:id
// @desc    Get a single conversation details
// @access  Private
// ─────────────────────────────────────────────────────────────
const getConversation = async (req, res) => {
  try {
    const { id: conversationId } = req.params;
    const currentUserId = req.user.id;

    // Verify user is a participant
    const participant = await ConversationParticipant.findOne({
      where: {
        conversation_id: conversationId,
        user_id: currentUserId,
        left_at: null,
      },
    });

    if (!participant) {
      return errorResponse(
        res,
        404,
        'Conversation not found or you are not a participant.'
      );
    }

    const conversation = await Conversation.findByPk(
      conversationId,
      {
        include: [
          {
            model: User,
            as: 'participants',
            attributes: [
              'id', 'username', 'full_name',
              'profile_pic_url', 'is_verified',
            ],
            through: {
              attributes: ['role', 'nickname', 'is_muted'],
              where: { left_at: null },
            },
          },
        ],
      }
    );

    if (!conversation) {
      return errorResponse(res, 404, 'Conversation not found.');
    }

    return successResponse(
      res,
      200,
      'Conversation fetched',
      {
        conversation: formatConversation(
          conversation,
          currentUserId
        ),
      }
    );

  } catch (error) {
    console.error('❌ Get conversation error:', error);
    return errorResponse(
      res,
      500,
      'Failed to fetch conversation.'
    );
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/conversations/:id/messages
// @desc    Get messages in a conversation (paginated)
// @access  Private
// ─────────────────────────────────────────────────────────────
const getMessages = async (req, res) => {
  try {
    const { id: conversationId } = req.params;
    const currentUserId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const offset = (page - 1) * limit;

    // Verify participant
    const participant = await ConversationParticipant.findOne({
      where: {
        conversation_id: conversationId,
        user_id: currentUserId,
        left_at: null,
      },
    });

    if (!participant) {
      return errorResponse(
        res,
        403,
        'You are not a participant in this conversation.'
      );
    }

    // Get messages
    const { count, rows: messages } = await Message.findAndCountAll({
      where: { conversation_id: conversationId },
      include: [
        {
          model: User,
          as: 'sender',
          attributes: [
            'id', 'username', 'full_name', 'profile_pic_url',
          ],
        },
        {
          model: Message,
          as: 'repliedTo',
          attributes: ['id', 'content', 'is_deleted', 'sender_id'],
          required: false,
        },
      ],
      order: [['created_at', 'DESC']], // Newest first
      limit,
      offset,
    });

    // Auto-mark as read when fetching messages
    await participant.update({ last_read_at: new Date() });

    const formattedMessages = messages.map(formatMessage);

    return paginatedResponse(
      res,
      'Messages fetched',
      formattedMessages,
      {
        page,
        totalPages: Math.ceil(count / limit),
        totalItems: count,
        limit,
      }
    );

  } catch (error) {
    console.error('❌ Get messages error:', error);
    return errorResponse(res, 500, 'Failed to fetch messages.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/conversations/:id/messages
// @desc    Send a message in a conversation
// @access  Private
// ─────────────────────────────────────────────────────────────
const sendMessage = async (req, res) => {
  try {
    const { id: conversationId } = req.params;
    const senderId = req.user.id;
    const {
      content,
      message_type = 'text',
      reply_to_message_id,
      shared_post_id,
    } = req.body;

    // 1. VALIDATE
    if (!content && message_type === 'text') {
      return errorResponse(res, 400, 'Message content is required.');
    }

    if (content && content.length > 10000) {
      return errorResponse(
        res,
        400,
        'Message too long (max 10000 chars).'
      );
    }

    // 2. VERIFY PARTICIPANT
    const participant = await ConversationParticipant.findOne({
      where: {
        conversation_id: conversationId,
        user_id: senderId,
        left_at: null,
      },
    });

    if (!participant) {
      return errorResponse(
        res,
        403,
        'You are not a participant in this conversation.'
      );
    }

    // 3. VALIDATE REPLY (if replying)
    if (reply_to_message_id) {
      const replyTarget = await Message.findOne({
        where: {
          id: reply_to_message_id,
          conversation_id: conversationId,
        },
      });
      if (!replyTarget) {
        return errorResponse(
          res,
          404,
          'Message to reply to not found.'
        );
      }
    }

    // 4. CREATE MESSAGE
    const message = await Message.create({
      conversation_id: conversationId,
      sender_id: senderId,
      content: content || null,
      message_type,
      reply_to_message_id: reply_to_message_id || null,
      shared_post_id: shared_post_id || null,
      is_deleted: false,
    });

    // 5. UPDATE CONVERSATION LAST MESSAGE
    const preview = content
      ? content.substring(0, 100)
      : `Sent ${message_type === 'like' ? '❤️' : 'a ' + message_type}`;

    await Conversation.update(
      {
        last_message: preview,
        last_message_at: new Date(),
        last_message_sender_id: senderId,
      },
      { where: { id: conversationId } }
    );

    // 6. GET FULL MESSAGE WITH SENDER
    const fullMessage = await Message.findByPk(message.id, {
      include: [
        {
          model: User,
          as: 'sender',
          attributes: [
            'id', 'username', 'full_name', 'profile_pic_url',
          ],
        },
        {
          model: Message,
          as: 'repliedTo',
          attributes: ['id', 'content', 'is_deleted', 'sender_id'],
          required: false,
        },
      ],
    });

    const io = req.app.get('io');
    if (io) {
      const roomName = `conversation:${conversationId}`;
      const socketMessage = formatMessage(fullMessage);

      io.to(roomName).emit('new-message', {
        conversation_id: conversationId,
        message: socketMessage,
      });

      const allParticipants = await ConversationParticipant.findAll({
        where: {
          conversation_id: conversationId,
          user_id: { [Op.ne]: senderId },
          left_at: null,
        },
        attributes: ['user_id'],
        raw: true,
      });

      const lastMessageAt = new Date();
      allParticipants.forEach((participant) => {
        emitToUser(io, participant.user_id, 'inbox-update', {
          conversation_id: conversationId,
          last_message: preview,
          last_message_at: lastMessageAt,
        });
      });
    }

    console.log(
      `💬 Message sent in conversation ${conversationId}`
    );

    return successResponse(
      res,
      201,
      'Message sent successfully',
      { message: formatMessage(fullMessage) }
    );

  } catch (error) {
    console.error('❌ Send message error:', error);
    return errorResponse(res, 500, 'Failed to send message.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/messages/:id
// @desc    Unsend a message (soft delete)
// @access  Private (own messages only)
// ─────────────────────────────────────────────────────────────
const deleteMessage = async (req, res) => {
  try {
    const { id: messageId } = req.params;
    const currentUserId = req.user.id;

    const message = await Message.findByPk(messageId);

    if (!message) {
      return errorResponse(res, 404, 'Message not found.');
    }

    // Only sender can unsend
    if (message.sender_id !== currentUserId) {
      return errorResponse(
        res,
        403,
        'You can only unsend your own messages.'
      );
    }

    if (message.is_deleted) {
      return errorResponse(res, 400, 'Message already unsent.');
    }

    // Soft delete: mark as deleted, clear content
    await message.update({
      is_deleted: true,
      deleted_at: new Date(),
      content: null,
      media_url: null,
    });

    console.log(`🗑️  Message unsent: ${messageId}`);

    return successResponse(
      res,
      200,
      'Message unsent successfully.',
      { message_id: messageId, is_deleted: true }
    );

  } catch (error) {
    console.error('❌ Delete message error:', error);
    return errorResponse(res, 500, 'Failed to unsend message.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   PUT /api/v1/conversations/:id/read
// @desc    Mark conversation as read
// @access  Private
// ─────────────────────────────────────────────────────────────
const markAsRead = async (req, res) => {
  try {
    const { id: conversationId } = req.params;
    const currentUserId = req.user.id;

    await ConversationParticipant.update(
      { last_read_at: new Date() },
      {
        where: {
          conversation_id: conversationId,
          user_id: currentUserId,
        },
      }
    );

    return successResponse(
      res,
      200,
      'Conversation marked as read.',
      {}
    );

  } catch (error) {
    console.error('❌ Mark as read error:', error);
    return errorResponse(res, 500, 'Failed to mark as read.');
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/conversations/unread-count
// @desc    Get total unread message count across all conversations
// @access  Private
// ─────────────────────────────────────────────────────────────
const getUnreadCount = async (req, res) => {
  try {
    const currentUserId = req.user.id;

    // Get all conversations user is part of
    const participants = await ConversationParticipant.findAll({
      where: {
        user_id: currentUserId,
        left_at: null,
      },
      attributes: ['conversation_id', 'last_read_at'],
      raw: true,
    });

    let totalUnread = 0;

    for (const participant of participants) {
      const unreadCount = await Message.count({
        where: {
          conversation_id: participant.conversation_id,
          sender_id: { [Op.ne]: currentUserId },
          is_deleted: false,
          ...(participant.last_read_at && {
            created_at: { [Op.gt]: participant.last_read_at },
          }),
        },
      });
      totalUnread += unreadCount;
    }

    return successResponse(
      res,
      200,
      'Unread count fetched',
      { unread_count: totalUnread }
    );

  } catch (error) {
    console.error('❌ Get unread count error:', error);
    return errorResponse(
      res,
      500,
      'Failed to get unread count.'
    );
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/conversations/:id
// @desc    Leave/hide a conversation
// @access  Private
// ─────────────────────────────────────────────────────────────
const leaveConversation = async (req, res) => {
  try {
    const { id: conversationId } = req.params;
    const currentUserId = req.user.id;

    const participant = await ConversationParticipant.findOne({
      where: {
        conversation_id: conversationId,
        user_id: currentUserId,
        left_at: null,
      },
    });

    if (!participant) {
      return errorResponse(
        res,
        404,
        'You are not a participant in this conversation.'
      );
    }

    // Mark as left (soft delete)
    await participant.update({ left_at: new Date() });

    return successResponse(
      res,
      200,
      'Conversation hidden successfully.',
      {}
    );

  } catch (error) {
    console.error('❌ Leave conversation error:', error);
    return errorResponse(res, 500, 'Failed to leave conversation.');
  }
};

module.exports = {
  createOrGetConversation,
  getInbox,
  getConversation,
  getMessages,
  sendMessage,
  deleteMessage,
  markAsRead,
  getUnreadCount,
  leaveConversation,
};
