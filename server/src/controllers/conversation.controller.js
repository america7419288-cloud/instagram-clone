// server/src/controllers/conversation.controller.js

const {
  Conversation,
  ConversationParticipant,
  Message,
  User,
  Post,
  PostMedia,
  Reel,
  Story,
  Block,
  Follower,
  sequelize,
} = require('../models');
const { getBlockedUserIds } = require('../utils/block.utils');
const {
  successResponse,
  errorResponse,
  paginatedResponse,
} = require('../utils/response.utils');
const { emitToUser, getIO } = require('../services/socket.service');
const { Op } = require('sequelize');
const { createMessageNotification } = require('../services/notification.service');
const {
  uploadImageToCloudinary,
  uploadVideoToCloudinary,
  uploadAudioToCloudinary,
  getMediaType,
} = require('../services/upload.service');

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
    last_message: c.last_message ? {
      id: "preview",
      content: c.last_message,
      created_at: c.last_message_at,
      sender_id: c.last_message_sender_id || null,
      conversation_id: c.id
    } : null,
    last_message_at: c.last_message_at,
    participants: (c.participants || []).map((p) => ({
      id: p.id,
      username: p.username,
      full_name: p.fullName || p.full_name,
      profile_pic_url: p.profile_pic_url,
      is_verified: p.is_verified,
    })),
    other_user: otherUser
      ? {
          id: otherUser.id,
          username: otherUser.username,
          full_name: otherUser.fullName || otherUser.full_name,
          profile_pic_url: otherUser.profile_pic_url,
          is_verified: otherUser.is_verified,
        }
      : null,
    unread_count: c.unread_count || 0,
    disappearing_duration: c.disappearing_duration || null,
    is_accepted: (() => {
      const myParticipant = (c.participantRecords || []).find(p => p.user_id === currentUserId) 
        || (conv.participantRecords || []).find(p => p.user_id === currentUserId);
      return myParticipant ? myParticipant.is_accepted : true;
    })(),
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
    is_edited: m.is_edited || false,
    edited_at: m.edited_at || null,
    expires_at: m.expires_at || null,
    created_at: m.created_at || m.createdAt,
    conversation_id: m.conversation_id || m.conversationId,
    sender_id: m.sender_id || m.senderId,

    // Who sent it
    sender: m.sender
      ? {
          id: m.sender.id,
          username: m.sender.username,
          full_name: m.sender.fullName || m.sender.full_name,
          profile_pic_url: m.sender.profile_pic_url,
        }
      : null,

    reply_to_id: m.reply_to_message_id,

    // If replying to another message
    reply_to_message: m.repliedTo
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
          caption: m.sharedPost.caption,
          thumbnail: m.sharedPost.mediaFiles?.[0]?.thumbnailUrl || m.sharedPost.mediaFiles?.[0]?.url,
          user: m.sharedPost.user,
        }
      : null,

    // Shared reel info
    shared_reel: m.sharedReel
      ? {
          id: m.sharedReel.id,
          caption: m.sharedReel.caption,
          thumbnail: m.sharedReel.thumbnailUrl,
          user: m.sharedReel.user,
        }
      : null,

    // Shared story info
    shared_story: m.sharedStory
      ? {
          id: m.sharedStory.id,
          media_url: m.sharedStory.media_url,
          thumbnail: m.sharedStory.thumbnail_url || m.sharedStory.media_url,
          media_type: m.sharedStory.media_type,
          caption: m.sharedStory.caption,
          user: m.sharedStory.user,
        }
      : null,
    
    postId: m.shared_post_id,
    reelId: m.message_type === 'reel' ? m.shared_post_id : null,
    storyId: m.message_type === 'story' ? m.shared_post_id : null,
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

    // 2.1 CHECK IF BLOCKED
    const blockedUserIds = await getBlockedUserIds(currentUserId);
    if (blockedUserIds.includes(targetUserId)) {
      return errorResponse(res, 403, 'You cannot message this user.');
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
          {
            model: ConversationParticipant,
            as: 'participantRecords',
            where: { conversation_id: existingConversation.id },
            attributes: ['last_read_at', 'is_muted', 'is_accepted', 'user_id'],
            required: false,
          }
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

    // Check follows in either direction
    const followAtoB = await Follower.findOne({
      where: {
        follower_id: currentUserId,
        following_id: targetUserId,
        status: 'accepted',
      },
    });

    const followBtoA = await Follower.findOne({
      where: {
        follower_id: targetUserId,
        following_id: currentUserId,
        status: 'accepted',
      },
    });

    const isMutualOrSingleFollow = !!(followAtoB || followBtoA);

    // 5. ADD BOTH USERS AS PARTICIPANTS
    await ConversationParticipant.bulkCreate([
      {
        conversation_id: conversation.id,
        user_id: currentUserId,
        role: 'member',
        is_accepted: true,
      },
      {
        conversation_id: conversation.id,
        user_id: targetUserId,
        role: 'member',
        is_accepted: isMutualOrSingleFollow,
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
        {
          model: ConversationParticipant,
          as: 'participantRecords',
          where: { conversation_id: conversation.id },
          attributes: ['last_read_at', 'is_muted', 'is_accepted', 'user_id'],
          required: false,
        }
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
    const isRequests = req.query.requests === 'true';

    console.log(`📬 Fetching inbox for user: ${currentUserId} (Page: ${page}, Limit: ${limit}, Requests: ${isRequests})`);

    // 1. Get all conversations where current user is a participant and match requests filter
    const participantRecords = await ConversationParticipant.findAll({
      where: {
        user_id: currentUserId,
        left_at: null,
        is_accepted: !isRequests,
      },
      attributes: ['conversation_id'],
    });

    const conversationIds = participantRecords.map(p => p.conversation_id);

    if (conversationIds.length === 0) {
      console.log('📭 User has no conversations matching filter.');
      const requestCount = isRequests ? 0 : await ConversationParticipant.count({
        where: {
          user_id: currentUserId,
          left_at: null,
          is_accepted: false,
        },
      });
      return paginatedResponse(res, 'Inbox is empty', [], {
        page,
        totalPages: 0,
        totalItems: 0,
        limit,
        request_count: requestCount,
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
          attributes: ['last_read_at', 'is_muted', 'is_accepted'],
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

    console.log(`✅ Found ${conversations.length} conversations matching filter.`);

    const activeConversationIds = conversations.map(c => c.id);
    const [unreadRows] = await sequelize.query(`
      SELECT
        m.conversation_id,
        COUNT(m.id) AS unread_count
      FROM messages m
      JOIN conversation_participants cp
        ON cp.conversation_id = m.conversation_id
       AND cp.user_id = :userId
      WHERE
        m.conversation_id IN (:conversationIds)
        AND m.sender_id  != :userId
        AND m.is_deleted  = false
        AND (
          cp.last_read_at IS NULL
          OR m.created_at > cp.last_read_at
        )
      GROUP BY m.conversation_id
    `, {
      replacements: {
        userId: currentUserId,
        conversationIds: activeConversationIds,
      },
      type: sequelize.QueryTypes.SELECT,
    });

    const unreadCountByConversationId = new Map(
      (unreadRows || []).map(u => [u.conversation_id, parseInt(u.unread_count, 10)])
    );

    // 2.1 Filter out conversations with blocked users
    const blockedUserIds = await getBlockedUserIds(currentUserId);
    
    // 3. Format conversations
    const formattedConversations = conversations
      .map((conv) => {
        const formatted = formatConversation(conv, currentUserId);
        formatted.unread_count = unreadCountByConversationId.get(conv.id) || 0;
        return formatted;
      })
      .filter((conv) => {
        if (!conv.is_group && conv.other_user) {
          return !blockedUserIds.includes(conv.other_user.id);
        }
        return true;
      });

    // Count pending message requests if not already in requests view
    const requestCount = isRequests ? 0 : await ConversationParticipant.count({
      where: {
        user_id: currentUserId,
        left_at: null,
        is_accepted: false,
      },
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
        request_count: requestCount,
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
          {
            model: ConversationParticipant,
            as: 'participantRecords',
            where: { conversation_id: conversationId },
            attributes: ['last_read_at', 'is_muted', 'is_accepted', 'user_id'],
            required: false,
          }
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
        {
          model: Post,
          as: 'sharedPost',
          attributes: ['id', 'caption'],
          include: [
            { model: User, as: 'user', attributes: ['username', 'profile_pic_url'] },
            { model: PostMedia, as: 'mediaFiles', attributes: ['url', 'thumbnailUrl'], limit: 1 }
          ],
          required: false,
        },
        {
          model: Reel,
          as: 'sharedReel',
          attributes: ['id', 'caption', 'thumbnailUrl'],
          include: [{ model: User, as: 'user', attributes: ['username', 'profile_pic_url'] }],
          required: false,
        },
        {
          model: Story,
          as: 'sharedStory',
          attributes: ['id', 'media_url', 'thumbnail_url', 'media_type', 'caption'],
          include: [{ model: User, as: 'user', attributes: ['username', 'profile_pic_url'] }],
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
      temp_id,
    } = req.body;

    console.log('📨 Send message request:', {
      conversationId,
      senderId,
      content: content?.substring(0, 50),
      message_type,
      temp_id,
    });

    // 1. VALIDATE
    if (!content && (message_type === 'text' || message_type === 'reply') && !req.file && !shared_post_id) {
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

    console.log('👤 Participant check:', { found: !!participant });

    if (!participant) {
      return errorResponse(
        res,
        403,
        'You are not a participant in this conversation.'
      );
    }

    // 2.1 CHECK IF BLOCKED (for DMs)
    const conversation = await Conversation.findByPk(conversationId, {
      include: [{ model: User, as: 'participants', attributes: ['id'] }]
    });

    if (conversation && !conversation.is_group) {
      const otherParticipant = conversation.participants.find(p => p.id !== senderId);
      if (otherParticipant) {
        const blockedUserIds = await getBlockedUserIds(senderId);
        if (blockedUserIds.includes(otherParticipant.id)) {
          return errorResponse(res, 403, 'You cannot send messages to this user.');
        }
      }
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

    // 3.5 UPLOAD MEDIA (if file attached)
    let mediaUrl = null;
    let resolvedMessageType = message_type;

    if (req.file) {
      console.log(`📤 Uploading message media: ${req.file.mimetype}`);
      const fileMediaType = getMediaType(req.file.mimetype);

      let uploadResult;
      if (fileMediaType === 'video') {
        uploadResult = await uploadVideoToCloudinary(
          req.file.buffer,
          req.file.mimetype,
          'instagram-clone/messages'
        );
        resolvedMessageType = 'video';
      } else if (fileMediaType === 'audio') {
        uploadResult = await uploadAudioToCloudinary(
          req.file.buffer,
          req.file.mimetype,
          'instagram-clone/messages/audio'
        );
        resolvedMessageType = 'audio';
      } else {
        uploadResult = await uploadImageToCloudinary(
          req.file.buffer,
          req.file.mimetype,
          'instagram-clone/messages'
        );
        resolvedMessageType = 'image';
      }

      mediaUrl = uploadResult.url;
      console.log(`✅ Message media uploaded: ${mediaUrl}`);
    }

    // Calculate disappearing message expiration
    let expiresAt = null;
    if (conversation && conversation.disappearing_duration && conversation.disappearing_duration > 0) {
      expiresAt = new Date(Date.now() + conversation.disappearing_duration * 1000);
    }

    // 4. CREATE MESSAGE
    console.log('💾 Creating message in database...');
    const message = await Message.create({
      conversation_id: conversationId,
      sender_id: senderId,
      content: content || null,
      media_url: mediaUrl,
      message_type: resolvedMessageType,
      reply_to_message_id: reply_to_message_id || null,
      shared_post_id: shared_post_id || null,
      is_deleted: false,
      expires_at: expiresAt,
    });
    console.log('✅ Message created:', message.id);

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

    // 5b. STAMP SENDER'S last_read_at — sending a message means you've read
    //     everything up to this moment, so your own inbox won't show unread dot.
    await ConversationParticipant.update(
      { last_read_at: new Date() },
      {
        where: {
          conversation_id: conversationId,
          user_id: senderId,
        },
      }
    );
    // 6. GET FULL MESSAGE WITH SENDER
    console.log('🔍 Fetching full message with associations...');
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
        {
          model: Post,
          as: 'sharedPost',
          attributes: ['id', 'caption'],
          include: [
            { model: User, as: 'user', attributes: ['username', 'profile_pic_url'] },
            { model: PostMedia, as: 'mediaFiles', attributes: ['url', 'thumbnailUrl'], limit: 1 }
          ],
          required: false,
        },
        {
          model: Reel,
          as: 'sharedReel',
          attributes: ['id', 'caption', 'thumbnailUrl'],
          include: [{ model: User, as: 'user', attributes: ['username', 'profile_pic_url'] }],
          required: false,
        },
        {
          model: Story,
          as: 'sharedStory',
          attributes: ['id', 'media_url', 'thumbnail_url', 'media_type', 'caption'],
          include: [{ model: User, as: 'user', attributes: ['username', 'profile_pic_url'] }],
          required: false,
        },
      ],
    });
    console.log('✅ Full message fetched successfully');

    const io = req.app.get('io');
    if (io) {
      const roomName = `conversation:${conversationId}`;
      const socketMessage = formatMessage(fullMessage);
      if (temp_id) socketMessage.temp_id = temp_id;

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
          last_message: {
            id: message.id,
            content: preview,
            created_at: lastMessageAt,
            sender_id: senderId,
            conversation_id: conversationId,
          },
          last_message_at: lastMessageAt,
        });
      });

      // ─── Push notification ─────────────────────────────────
      // Find all participants except sender
      try {
        const participants = await ConversationParticipant.findAll({
          where: {
            conversation_id: conversationId,
            user_id: { [Op.ne]: senderId },
          },
          attributes: ['user_id'],
        });

        // Send push to each recipient
        for (const participant of participants) {
          await createMessageNotification({
            recipientId: participant.userId || participant.user_id,
            senderId,
            conversationId: conversationId,
            messageText: content,
          });
        }
      } catch (pushError) {
        // Non-fatal: don't fail the message send
        console.error('Push notification error:', pushError.message);
      }
    }

    console.log(
      `💬 Message sent in conversation ${conversationId}`
    );

    return successResponse(
      res,
      201,
      'Message sent successfully',
      { message: { ...formatMessage(fullMessage), temp_id } }
    );

  } catch (error) {
    console.error('❌ Send message error:', error);
    console.error('Error details:', {
      message: error.message,
      stack: error.stack,
      name: error.name,
    });
    return errorResponse(res, 500, `Failed to send message: ${error.message}`);
  }
};

// ─────────────────────────────────────────────────────────────
// @route   DELETE /api/v1/messages/:id
// @desc    Unsend a message (soft delete)
// @access  Private (own messages only)
// ─────────────────────────────────────────────────────────────
const deleteMessage = async (req, res) => {
  try {
    // Supports both route shapes:
    //   DELETE /api/v1/messages/:id  (legacy)
    //   DELETE /api/v1/conversations/:id/messages/:messageId  (client)
    const messageId = req.params.messageId || req.params.id;
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

    // Update conversation's last message if this was the last message
    const lastMessage = await Message.findOne({
      where: {
        conversation_id: message.conversation_id,
        is_deleted: false,
      },
      order: [['created_at', 'DESC']],
    });

    let preview = null;
    let lastMessageAt = new Date();
    let lastMessageSenderId = null;

    if (lastMessage) {
      preview = lastMessage.content
        ? lastMessage.content.substring(0, 100)
        : `Sent ${lastMessage.message_type === 'like' ? '❤️' : 'a ' + lastMessage.message_type}`;
      lastMessageAt = lastMessage.createdAt || lastMessage.created_at;
      lastMessageSenderId = lastMessage.sender_id;
    }

    await Conversation.update(
      {
        last_message: preview,
        last_message_at: lastMessageAt,
        last_message_sender_id: lastMessageSenderId,
      },
      { where: { id: message.conversation_id } }
    );

    // ─── Broadcast deletion to conversation room in real-time ───
    const io = getIO();
    if (io) {
      const roomName = `conversation:${message.conversation_id}`;
      io.to(roomName).emit('message-deleted', {
        conversation_id: message.conversation_id,
        message_id: messageId,
        deleted_by: currentUserId,
        deleted_at: new Date(),
      });

      // Notify all participants about the inbox update to dynamically refresh their list
      const allParticipants = await ConversationParticipant.findAll({
        where: {
          conversation_id: message.conversation_id,
          left_at: null,
        },
        attributes: ['user_id'],
        raw: true,
      });

      const senderUser = await User.findByPk(currentUserId, { attributes: ['username'] });
      const senderUsername = senderUser ? senderUser.username : 'User';

      allParticipants.forEach((p) => {
        emitToUser(io, p.user_id, 'inbox-update', {
          conversation_id: message.conversation_id,
          last_message: preview || 'Message unsent',
          last_message_at: lastMessageAt,
          sender_username: senderUsername,
        });
      });
    }

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

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/conversations/:id/debug
// @desc    Debug conversation and participant status
// @access  Private
// ─────────────────────────────────────────────────────────────
const debugConversation = async (req, res) => {
  try {
    const { id: conversationId } = req.params;
    const userId = req.user.id;

    // Check conversation exists
    const conversation = await Conversation.findByPk(conversationId, {
      include: [
        {
          model: User,
          as: 'participants',
          attributes: ['id', 'username', 'full_name'],
        },
      ],
    });

    // Check participant status
    const participant = await ConversationParticipant.findOne({
      where: {
        conversation_id: conversationId,
        user_id: userId,
      },
    });

    // Check user exists
    const user = await User.findByPk(userId, {
      attributes: ['id', 'username', 'full_name', 'email'],
    });

    // Get recent messages count
    const messageCount = await Message.count({
      where: { conversation_id: conversationId },
    });

    // Check database connection
    let dbConnected = false;
    try {
      await sequelize.authenticate();
      dbConnected = true;
    } catch (dbError) {
      dbConnected = false;
    }

    return res.json({
      success: true,
      debug_info: {
        conversation: {
          exists: !!conversation,
          id: conversation?.id,
          is_group: conversation?.is_group,
          participant_count: conversation?.participants?.length || 0,
          participants: conversation?.participants?.map(p => ({
            id: p.id,
            username: p.username,
          })) || [],
        },
        participant: {
          exists: !!participant,
          is_active: participant && !participant.left_at,
          joined_at: participant?.joined_at,
          left_at: participant?.left_at,
          last_read_at: participant?.last_read_at,
        },
        user: {
          exists: !!user,
          id: user?.id,
          username: user?.username,
          full_name: user?.full_name,
        },
        messages: {
          count: messageCount,
        },
        database: {
          connected: dbConnected,
        },
        request: {
          conversation_id: conversationId,
          user_id: userId,
        },
      },
    });
  } catch (error) {
    console.error('❌ Debug conversation error:', error);
    return res.json({
      success: false,
      error: {
        message: error.message,
        name: error.name,
        stack: error.stack,
      },
    });
  }
};

// ─────────────────────────────────────────────────────────────
// @route   PUT /api/v1/conversations/:id/messages/:messageId
// @desc    Edit a text message content
// @access  Private (own text messages only)
// ─────────────────────────────────────────────────────────────
const editMessage = async (req, res) => {
  try {
    const { id: conversationId, messageId } = req.params;
    const { content } = req.body;
    const currentUserId = req.user.id;

    if (!content || content.trim().length === 0) {
      return errorResponse(res, 400, 'Content is required to edit message.');
    }

    // Verify user is a participant
    const participant = await ConversationParticipant.findOne({
      where: { conversation_id: conversationId, user_id: currentUserId, left_at: null },
    });
    if (!participant) {
      return errorResponse(res, 403, 'You are not a participant in this conversation.');
    }

    const message = await Message.findOne({
      where: { id: messageId, conversation_id: conversationId },
      include: [{ model: User, as: 'sender', attributes: ['id', 'username', 'full_name', 'profile_pic_url'] }]
    });

    if (!message) {
      return errorResponse(res, 404, 'Message not found.');
    }

    if (message.sender_id !== currentUserId) {
      return errorResponse(res, 403, 'You can only edit your own messages.');
    }

    if (message.is_deleted) {
      return errorResponse(res, 400, 'Cannot edit an unsent message.');
    }

    if (message.message_type !== 'text') {
      return errorResponse(res, 400, 'Only text messages can be edited.');
    }

    await message.update({
      content,
      is_edited: true,
      edited_at: new Date(),
    });

    const updatedMessage = formatMessage(message);

    // Broadcast update via socket.io
    const io = req.app.get('io');
    if (io) {
      io.to(`conversation:${conversationId}`).emit('message-edited', {
        conversation_id: conversationId,
        message: updatedMessage,
      });
    }

    return successResponse(res, 200, 'Message edited successfully.', { message: updatedMessage });
  } catch (error) {
    console.error('❌ Edit message error:', error);
    return errorResponse(res, 500, 'Failed to edit message.', error.message);
  }
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/conversations/group
// @desc    Create a new group conversation
// @access  Private
// ─────────────────────────────────────────────────────────────
const createGroupConversation = async (req, res) => {
  try {
    const creatorId = req.user.id;
    const { name, participant_ids, avatar_url } = req.body;

    if (!name || name.trim().length === 0) {
      return errorResponse(res, 400, 'Group name is required.');
    }

    if (!participant_ids || !Array.isArray(participant_ids) || participant_ids.length === 0) {
      return errorResponse(res, 400, 'At least one participant is required.');
    }

    // Ensure all participant IDs are unique and do not include the creator
    const uniqueUserIds = Array.from(new Set(participant_ids.filter(id => id !== creatorId)));

    // Verify all target users exist
    const validUsers = await User.findAll({
      where: { id: { [Op.in]: uniqueUserIds } },
      attributes: ['id', 'username']
    });

    if (validUsers.length !== uniqueUserIds.length) {
      return errorResponse(res, 400, 'One or more participant users do not exist.');
    }

    // Create the conversation model
    const conversation = await Conversation.create({
      name: name.trim(),
      avatar_url: avatar_url || null,
      is_group: true,
      created_by: creatorId,
      last_message: 'Group created',
      last_message_at: new Date(),
      last_message_sender_id: creatorId,
    });

    // Add creator as admin and others as members
    const participantsData = [
      {
        conversation_id: conversation.id,
        user_id: creatorId,
        role: 'admin',
      },
      ...uniqueUserIds.map(uid => ({
        conversation_id: conversation.id,
        user_id: uid,
        role: 'member',
      }))
    ];

    await ConversationParticipant.bulkCreate(participantsData);

    // Retrieve the full conversation with all participants included
    const fullConversation = await Conversation.findByPk(conversation.id, {
      include: [
        {
          model: User,
          as: 'participants',
          attributes: ['id', 'username', 'full_name', 'profile_pic_url', 'is_verified'],
          through: { attributes: ['role'] },
        },
      ],
    });

    const formatted = formatConversation(fullConversation, creatorId);

    // Notify all participants over socket about the new inbox conversation
    const io = req.app.get('io');
    if (io) {
      const allParticipantIds = [creatorId, ...uniqueUserIds];
      allParticipantIds.forEach((uid) => {
        emitToUser(io, uid, 'inbox-update', {
          conversation_id: conversation.id,
          last_message: {
            id: 'system',
            content: 'Group created',
            created_at: new Date(),
            sender_id: creatorId,
            conversation_id: conversation.id,
          },
          last_message_at: new Date(),
        });
      });
    }

    return successResponse(res, 201, 'Group conversation created successfully.', {
      conversation: formatted,
    });

  } catch (error) {
    console.error('❌ Create group error:', error);
    return errorResponse(res, 500, 'Failed to create group conversation.', error.message);
  }
};

// ─────────────────────────────────────────────────────────────
// @route   PUT /api/v1/conversations/:id/disappearing
// @desc    Set conversation disappearing messages configuration
// @access  Private (participants only)
// ─────────────────────────────────────────────────────────────
const setDisappearingMessages = async (req, res) => {
  try {
    const { id: conversationId } = req.params;
    const { duration } = req.body; // duration in seconds (e.g. 86400, or 0/null to disable)
    const currentUserId = req.user.id;

    // Verify user is a participant
    const participant = await ConversationParticipant.findOne({
      where: { conversation_id: conversationId, user_id: currentUserId, left_at: null },
    });
    if (!participant) {
      return errorResponse(res, 403, 'You are not a participant in this conversation.');
    }

    const conversation = await Conversation.findByPk(conversationId);
    if (!conversation) {
      return errorResponse(res, 404, 'Conversation not found.');
    }

    const durationVal = duration ? parseInt(duration) : null;

    await conversation.update({
      disappearing_duration: durationVal,
    });

    // Broadcast mode change via socket
    const io = req.app.get('io');
    if (io) {
      io.to(`conversation:${conversationId}`).emit('disappearing-mode-changed', {
        conversation_id: conversationId,
        disappearing_duration: durationVal,
        changed_by: currentUserId,
      });
    }

    return successResponse(res, 200, 'Disappearing messages configuration updated.', {
      conversation_id: conversationId,
      disappearing_duration: durationVal,
    });

  } catch (error) {
    console.error('❌ Set disappearing mode error:', error);
    return errorResponse(res, 500, 'Failed to set disappearing messages.', error.message);
  }
};

// ─────────────────────────────────────────────────────────────
// @route   GET /api/v1/conversations/:id/search
// @desc    Search conversation historical messages
// @access  Private (participants only)
// ─────────────────────────────────────────────────────────────
const searchMessages = async (req, res) => {
  try {
    const { id: conversationId } = req.params;
    const { query } = req.query;
    const currentUserId = req.user.id;

    if (!query || query.trim().length === 0) {
      return errorResponse(res, 400, 'Search query is required.');
    }

    // Verify participant
    const participant = await ConversationParticipant.findOne({
      where: { conversation_id: conversationId, user_id: currentUserId, left_at: null },
    });

    if (!participant) {
      return errorResponse(res, 403, 'You are not a participant in this conversation.');
    }

    // Search messages using SQL LIKE operator
    const messages = await Message.findAll({
      where: {
        conversation_id: conversationId,
        is_deleted: false,
        content: {
          [Op.iLike]: `%${query.trim()}%`
        }
      },
      include: [
        {
          model: User,
          as: 'sender',
          attributes: ['id', 'username', 'full_name', 'profile_pic_url'],
        }
      ],
      order: [['created_at', 'DESC']],
      limit: 50
    });

    const formatted = messages.map(formatMessage);

    return successResponse(res, 200, 'Messages searched successfully.', {
      query,
      results: formatted
    });

  } catch (error) {
    console.error('❌ Search messages error:', error);
    return errorResponse(res, 500, 'Failed to search messages.', error.message);
  }
};

// ─────────────────────────────────────────────────────────────
// @route   POST /api/v1/conversations/:id/messages/:messageId/react
// @desc    Add or remove an emoji reaction on a message
// @access  Private
// ─────────────────────────────────────────────────────────────
const reactToMessage = async (req, res) => {
  try {
    const { id: conversationId, messageId } = req.params;
    const currentUserId = req.user.id;
    const { emoji } = req.body;

    if (!emoji || typeof emoji !== 'string') {
      return errorResponse(res, 400, 'emoji field is required.');
    }

    const message = await Message.findOne({
      where: { id: messageId, conversation_id: conversationId },
    });

    if (!message) {
      return errorResponse(res, 404, 'Message not found.');
    }

    if (message.is_deleted) {
      return errorResponse(res, 400, 'Cannot react to a deleted message.');
    }

    // Build updated reactions map
    const reactions = { ...(message.reactions || {}) };
    let alreadyReactedToSameEmoji = false;

    // Remove this user from all emoji reactions first
    for (const key of Object.keys(reactions)) {
      const users = reactions[key] ? [...reactions[key]] : [];
      if (users.includes(currentUserId)) {
        if (key === emoji) {
          alreadyReactedToSameEmoji = true;
        }
        reactions[key] = users.filter((uid) => uid !== currentUserId);
        if (reactions[key].length === 0) {
          delete reactions[key];
        }
      }
    }

    // If they reacted to a different emoji, add the user's reaction
    if (!alreadyReactedToSameEmoji) {
      const targetUsers = reactions[emoji] ? [...reactions[emoji]] : [];
      reactions[emoji] = [...targetUsers, currentUserId];
    }

    await message.update({ reactions });

    // ─── Broadcast to conversation room ───────────────────────
    const io = getIO();
    if (io) {
      const roomName = `conversation:${conversationId}`;
      io.to(roomName).emit('message-reacted', {
        conversation_id: conversationId,
        message_id: messageId,
        reactions,
        reacted_by: currentUserId,
        emoji,
        action: alreadyReactedToSameEmoji ? 'removed' : 'added',
      });
    }

    return successResponse(res, 200, 'Reaction updated.', { reactions });

  } catch (error) {
    console.error('❌ React to message error:', error);
    return errorResponse(res, 500, 'Failed to update reaction.');
  }
};

const acceptConversationRequest = async (req, res) => {
  try {
    const { id: conversationId } = req.params;
    const currentUserId = req.user.id;

    console.log(`👍 Accept Conversation: ${conversationId} for user ${currentUserId}`);

    const [updatedCount] = await ConversationParticipant.update(
      { is_accepted: true },
      {
        where: {
          conversation_id: conversationId,
          user_id: currentUserId,
          left_at: null,
        },
      }
    );

    if (updatedCount === 0) {
      return errorResponse(res, 404, 'Conversation request not found or already accepted.');
    }

    return successResponse(res, 200, 'Conversation request accepted successfully.');
  } catch (error) {
    console.error('❌ Accept conversation request error:', error);
    return errorResponse(res, 500, 'Failed to accept conversation request.', error.message);
  }
};

const rejectConversationRequest = async (req, res) => {
  try {
    const { id: conversationId } = req.params;
    const currentUserId = req.user.id;

    console.log(`👎 Reject Conversation: ${conversationId} for user ${currentUserId}`);

    const [updatedCount] = await ConversationParticipant.update(
      { left_at: new Date() },
      {
        where: {
          conversation_id: conversationId,
          user_id: currentUserId,
          left_at: null,
        },
      }
    );

    if (updatedCount === 0) {
      return errorResponse(res, 404, 'Conversation request not found or already rejected.');
    }

    return successResponse(res, 200, 'Conversation request rejected successfully.');
  } catch (error) {
    console.error('❌ Reject conversation request error:', error);
    return errorResponse(res, 500, 'Failed to reject conversation request.', error.message);
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
  debugConversation,
  editMessage,
  createGroupConversation,
  setDisappearingMessages,
  searchMessages,
  reactToMessage,
  acceptConversationRequest,
  rejectConversationRequest,
};
