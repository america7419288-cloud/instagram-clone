// server/src/services/socket.service.js
// This file handles ALL real-time functionality

const { Server } = require('socket.io');
const { verifyAccessToken } = require('../utils/jwt.utils');
const { User, ConversationParticipant, Message, Conversation } =
  require('../models');

const normalizeOrigin = (origin) => origin?.trim().replace(/\/$/, '');

const allowedOrigins = [
  process.env.CLIENT_URL,
  process.env.CORS_ORIGIN,
  process.env.CORS_ORIGINS,
]
  .filter(Boolean)
  .flatMap((origin) => origin.split(','))
  .map(normalizeOrigin)
  .filter(Boolean);

const allowAllOrigins = allowedOrigins.includes('*');

const isProduction =
  process.env.NODE_ENV === 'production' ||
  process.env.MODE_ENV === 'production';

const validateSocketOrigin = (origin, callback) => {
  const requestOrigin = normalizeOrigin(origin);

  if (
    !requestOrigin ||
    !isProduction ||
    allowAllOrigins ||
    allowedOrigins.includes(requestOrigin)
  ) {
    return callback(null, true);
  }

  console.warn(`Blocked by Socket.io CORS: ${requestOrigin}`);
  return callback(new Error('Not allowed by Socket.io CORS'));
};

// ─── TRACK ONLINE USERS ────────────────────────────────────
// Map: userId → Set of socketIds (user can have multiple tabs)
const onlineUsers = new Map();

// Map: socketId → userId (for disconnect lookup)
const socketToUser = new Map();

// ─── HELPER: Add online user ───────────────────────────────
const addOnlineUser = (userId, socketId) => {
  if (!onlineUsers.has(userId)) {
    onlineUsers.set(userId, new Set());
  }
  onlineUsers.get(userId).add(socketId);
  socketToUser.set(socketId, userId);
};

// ─── HELPER: Remove online user ────────────────────────────
const removeOnlineUser = (socketId) => {
  const userId = socketToUser.get(socketId);
  if (userId) {
    const userSockets = onlineUsers.get(userId);
    if (userSockets) {
      userSockets.delete(socketId);
      if (userSockets.size === 0) {
        onlineUsers.delete(userId);
      }
    }
    socketToUser.delete(socketId);
  }
  return userId;
};

// ─── HELPER: Is user online ────────────────────────────────
const isUserOnline = (userId) => {
  return (
    onlineUsers.has(userId) &&
    onlineUsers.get(userId).size > 0
  );
};

// ─── HELPER: Get all online user IDs ───────────────────────
const getOnlineUserIds = () => {
  return Array.from(onlineUsers.keys());
};

// ─── HELPER: Emit to all sockets of a user ─────────────────
const emitToUser = (io, userId, event, data) => {
  const userSockets = onlineUsers.get(userId);
  if (userSockets) {
    userSockets.forEach((socketId) => {
      io.to(socketId).emit(event, data);
    });
  }
};

// ─── SETUP SOCKET SERVER ───────────────────────────────────
const setupSocketServer = (httpServer) => {
  const io = new Server(httpServer, {
    cors: {
      origin: validateSocketOrigin,
      methods: ['GET', 'POST'],
      credentials: true,
    },
    // Ping timeout settings
    pingTimeout: 60000,
    pingInterval: 25000,
    // Max message size
    maxHttpBufferSize: 1e7, // 10 MB
  });

  // ─── MIDDLEWARE: JWT Authentication ──────────────────────
  // Runs before every connection
  io.use(async (socket, next) => {
    try {
      const token =
        socket.handshake.auth?.token ||
        socket.handshake.headers?.authorization?.split(' ')[1];

      if (!token) {
        return next(
          new Error('Authentication required. No token provided.')
        );
      }

      // Verify token
      const decoded = verifyAccessToken(token);
      if (!decoded) {
        return next(
          new Error('Invalid or expired token.')
        );
      }

      // Get user from database
      const user = await User.findByPk(decoded.id, {
        attributes: [
          'id', 'username', 'profile_pic_url',
          'is_active', 'is_banned',
        ],
      });

      if (!user || !user.is_active || user.is_banned) {
        return next(new Error('User not found or account suspended.'));
      }

      // Attach user to socket
      socket.userId = user.id;
      socket.username = user.username;
      socket.profilePicUrl = user.profile_pic_url;

      console.log(
        `🔌 Socket auth: ${user.username} (${socket.id})`
      );

      next(); // Allow connection
    } catch (error) {
      console.error('Socket auth error:', error.message);
      next(new Error('Authentication failed.'));
    }
  });

  // ─── CONNECTION HANDLER ───────────────────────────────────
  io.on('connection', (socket) => {
    const userId = socket.userId;
    const username = socket.username;

    console.log(`✅ Connected: ${username} (${socket.id})`);

    // Track this user as online
    addOnlineUser(userId, socket.id);

    // Update last_active_at in database
    User.update(
      { last_active_at: new Date() },
      { where: { id: userId } }
    ).catch(console.error);

    // Tell other users this person is now online
    socket.broadcast.emit('user-online', {
      user_id: userId,
      username,
      is_online: true,
    });

    // Send currently online users to the newly connected user
    socket.emit('online-users', {
      online_user_ids: getOnlineUserIds(),
    });

    // ─── EVENT: JOIN CONVERSATION ROOM ─────────────────────
    // Client calls this when they open a chat
    socket.on('join-room', async ({ conversation_id }) => {
      try {
        if (!conversation_id) return;

        // Verify user is a participant in this conversation
        const participant = await ConversationParticipant.findOne({
          where: {
            conversation_id,
            user_id: userId,
            left_at: null,
          },
        });

        if (!participant) {
          socket.emit('error', {
            message: 'You are not a participant in this conversation.',
          });
          return;
        }

        // Join the Socket.io room for this conversation
        const roomName = `conversation:${conversation_id}`;
        socket.join(roomName);

        console.log(
          `📥 ${username} joined room: ${roomName}`
        );

        // Let others in room know this user is here
        socket.to(roomName).emit('user-joined-room', {
          conversation_id,
          user_id: userId,
          username,
        });

        // Update last_read_at (they're viewing the conversation)
        await participant.update({ last_read_at: new Date() });

        socket.emit('joined-room', {
          conversation_id,
          message: `Joined conversation room successfully`,
        });

      } catch (error) {
        console.error('Join room error:', error.message);
        socket.emit('error', { message: 'Failed to join room.' });
      }
    });

    // ─── EVENT: LEAVE CONVERSATION ROOM ────────────────────
    socket.on('leave-room', ({ conversation_id }) => {
      const roomName = `conversation:${conversation_id}`;
      socket.leave(roomName);

      console.log(`📤 ${username} left room: ${roomName}`);

      socket.to(roomName).emit('user-left-room', {
        conversation_id,
        user_id: userId,
        username,
      });
    });

    // ─── EVENT: SEND MESSAGE ────────────────────────────────
    // When a message is sent via API, this broadcasts it
    // to all other participants in real-time
    socket.on(
      'send-message',
      async ({
        conversation_id,
        message_id,
        content,
        message_type = 'text',
        reply_to_message_id,
        temp_id,    // Temporary ID for optimistic UI
      }) => {
        try {
          if (!conversation_id || (!content && message_type === 'text')) {
            return;
          }

          // Verify participant
          const participant = await ConversationParticipant.findOne({
            where: {
              conversation_id,
              user_id: userId,
              left_at: null,
            },
          });

          if (!participant) return;

          // If message_id is provided, it was already saved via API
          // Just broadcast it to others in the room
          if (message_id) {
            const message = await Message.findByPk(message_id, {
              include: [
                {
                  model: User,
                  as: 'sender',
                  attributes: [
                    'id', 'username', 'full_name',
                    'profile_pic_url',
                  ],
                },
              ],
            });

            if (message) {
              const roomName = `conversation:${conversation_id}`;
              // Broadcast to ALL in room (including sender)
              io.to(roomName).emit('new-message', {
                conversation_id,
                message: {
                  id: message.id,
                  content: message.content,
                  message_type: message.message_type,
                  is_deleted: false,
                  created_at: message.createdAt,
                  conversation_id,
                  sender: {
                    id: message.sender.id,
                    username: message.sender.username,
                    full_name: message.sender.fullName,
                    profile_pic_url: message.sender.profile_pic_url,
                  },
                  replied_to: null,
                  temp_id, // Echo back temp_id so client can replace
                },
              });
            }
          }

          // Update last message in conversation
          await Conversation.update(
            {
              last_message: content
                ? content.substring(0, 100)
                : message_type === 'like'
                ? '❤️'
                : `Sent a ${message_type}`,
              last_message_at: new Date(),
              last_message_sender_id: userId,
            },
            { where: { id: conversation_id } }
          );

          // Notify participants who are NOT in the room
          // (they need an inbox update)
          const allParticipants =
            await ConversationParticipant.findAll({
              where: {
                conversation_id,
                user_id: { [require('sequelize').Op.ne]: userId },
                left_at: null,
              },
              attributes: ['user_id'],
              raw: true,
            });

          allParticipants.forEach((p) => {
            emitToUser(io, p.user_id, 'inbox-update', {
              conversation_id,
              last_message: content || '❤️',
              last_message_at: new Date(),
              sender_username: username,
            });
          });

        } catch (error) {
          console.error('Send message socket error:', error.message);
        }
      }
    );

    // ─── EVENT: TYPING INDICATOR ───────────────────────────
    socket.on('typing', ({ conversation_id }) => {
      const roomName = `conversation:${conversation_id}`;
      // Broadcast to others in room (not sender)
      socket.to(roomName).emit('user-typing', {
        conversation_id,
        user_id: userId,
        username,
        is_typing: true,
      });
    });

    // ─── EVENT: STOP TYPING ────────────────────────────────
    socket.on('stop-typing', ({ conversation_id }) => {
      const roomName = `conversation:${conversation_id}`;
      socket.to(roomName).emit('user-typing', {
        conversation_id,
        user_id: userId,
        username,
        is_typing: false,
      });
    });

    // ─── EVENT: MESSAGE READ ───────────────────────────────
    socket.on('message-read', async ({ conversation_id }) => {
      try {
        await ConversationParticipant.update(
          { last_read_at: new Date() },
          { where: { conversation_id, user_id: userId } }
        );

        // Tell other participants this user read the messages
        const roomName = `conversation:${conversation_id}`;
        socket.to(roomName).emit('messages-read', {
          conversation_id,
          read_by_user_id: userId,
          read_at: new Date(),
        });
      } catch (error) {
        console.error('Message read socket error:', error.message);
      }
    });

    // ─── EVENT: CHECK ONLINE STATUS ────────────────────────
    socket.on('check-online', ({ user_ids }) => {
      if (!Array.isArray(user_ids)) return;

      const statuses = {};
      user_ids.forEach((uid) => {
        statuses[uid] = isUserOnline(uid);
      });

      socket.emit('online-status', { statuses });
    });

    // ─── EVENT: DISCONNECT ─────────────────────────────────
    socket.on('disconnect', (reason) => {
      console.log(
        `❌ Disconnected: ${username} (${socket.id}) - ${reason}`
      );

      // Remove from online tracking
      const disconnectedUserId = removeOnlineUser(socket.id);

      if (disconnectedUserId) {
        // Update last_active_at
        User.update(
          { last_active_at: new Date() },
          { where: { id: disconnectedUserId } }
        ).catch(console.error);

        // If user has no more sockets, broadcast offline status
        if (!isUserOnline(disconnectedUserId)) {
          socket.broadcast.emit('user-offline', {
            user_id: disconnectedUserId,
            is_online: false,
            last_active: new Date(),
          });
        }
      }
    });

    // ─── EVENT: ERROR HANDLER ──────────────────────────────
    socket.on('error', (error) => {
      console.error(`Socket error for ${username}:`, error.message);
    });
  });

  console.log('✅ Socket.io server initialized');

  return io;
};

// ─── EXPORT HELPER FUNCTIONS ───────────────────────────────
// These can be used from other parts of the app
// e.g., emit notification when someone likes a post

module.exports = {
  setupSocketServer,
  isUserOnline,
  emitToUser,
  getOnlineUserIds,
  onlineUsers,
};
