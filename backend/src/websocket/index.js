const { Server } = require('socket.io');
const { verifyAccessToken } = require('../utils/jwt');
const { query } = require('../config/database');
const logger = require('../utils/logger');

let io = null;

const initializeWebSocket = (httpServer) => {
  io = new Server(httpServer, {
    cors: { origin: '*', methods: ['GET', 'POST'], credentials: true },
    pingTimeout: 60000,
    pingInterval: 25000
  });

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];
      if (!token) return next(new Error('Authentication required'));
      const decoded = verifyAccessToken(token);
      if (!decoded) return next(new Error('Invalid token'));
      const result = await query('SELECT id, name, avatar_url FROM users WHERE id = $1', [decoded.userId]);
      if (result.rows.length === 0) return next(new Error('User not found'));
      socket.user = result.rows[0];
      next();
    } catch (error) {
      logger.error('Socket auth error:', error);
      next(new Error('Authentication failed'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.user.id;
    const userName = socket.user.name;
    logger.info(`User connected: ${userId}`);
    socket.join(`user:${userId}`);
    await query('UPDATE users SET is_online = TRUE, last_seen = NOW() WHERE id = $1', [userId]);
    const chats = await query('SELECT chat_id FROM chat_members WHERE user_id = $1', [userId]);
    for (const chat of chats.rows) {
      socket.join(`chat:${chat.chat_id}`);
    }
    await notifyPresence(userId, 'online');

    socket.on('typing:start', async (data) => {
      const { chatId } = data;
      socket.to(`chat:${chatId}`).emit('typing:start', { chatId, userId, userName });
    });

    socket.on('typing:stop', async (data) => {
      const { chatId } = data;
      socket.to(`chat:${chatId}`).emit('typing:stop', { chatId, userId });
    });

    socket.on('message:delivered', async (data) => {
      const { messageId, chatId } = data;
      await query(
        `INSERT INTO message_status (message_id, user_id, status, status_at) VALUES ($1, $2, 'delivered', NOW())
         ON CONFLICT (message_id, user_id) DO UPDATE SET status = 'delivered', status_at = NOW()`,
        [messageId, userId]
      );
      const result = await query('SELECT sender_id FROM messages WHERE id = $1', [messageId]);
      if (result.rows.length > 0) {
        io.to(`user:${result.rows[0].sender_id}`).emit('message:status', { messageId, chatId, status: 'delivered', userId });
      }
    });

    socket.on('message:read', async (data) => {
      const { messageId, chatId } = data;
      await query(
        `INSERT INTO message_status (message_id, user_id, status, status_at) VALUES ($1, $2, 'read', NOW())
         ON CONFLICT (message_id, user_id) DO UPDATE SET status = 'read', status_at = NOW()`,
        [messageId, userId]
      );
      await query('UPDATE chat_members SET last_read_at = NOW(), unread_count = 0 WHERE chat_id = $1 AND user_id = $2', [chatId, userId]);
      const result = await query('SELECT sender_id FROM messages WHERE id = $1', [messageId]);
      if (result.rows.length > 0) {
        io.to(`user:${result.rows[0].sender_id}`).emit('message:status', { messageId, chatId, status: 'read', userId });
      }
    });

    socket.on('call:initiate', async (data) => {
      const { recipientId, callType, callId } = data;
      io.to(`user:${recipientId}`).emit('call:incoming', { callId, callerId: userId, callerName: userName, callerAvatar: socket.user.avatar_url, callType });
    });

    socket.on('call:accept', async (data) => {
      const { callId, callerId } = data;
      io.to(`user:${callerId}`).emit('call:accepted', { callId, recipientId: userId });
    });

    socket.on('call:reject', async (data) => {
      const { callId, callerId } = data;
      io.to(`user:${callerId}`).emit('call:rejected', { callId, recipientId: userId });
    });

    socket.on('call:end', async (data) => {
      const { callId, recipientId } = data;
      io.to(`user:${recipientId}`).emit('call:ended', { callId });
    });

    socket.on('call:signal', async (data) => {
      const { callId, targetUserId, signal } = data;
      io.to(`user:${targetUserId}`).emit('call:signal', { callId, fromUserId: userId, signal });
    });

    socket.on('call:ice-candidate', async (data) => {
      const { callId, targetUserId, candidate } = data;
      io.to(`user:${targetUserId}`).emit('call:ice-candidate', { callId, fromUserId: userId, candidate });
    });

    socket.on('disconnect', async () => {
      logger.info(`User disconnected: ${userId}`);
      const sockets = await io.in(`user:${userId}`).fetchSockets();
      if (sockets.length === 0) {
        await query('UPDATE users SET is_online = FALSE, last_seen = NOW() WHERE id = $1', [userId]);
        await notifyPresence(userId, 'offline');
      }
    });
  });

  return io;
};

const notifyPresence = async (userId, status) => {
  const contacts = await query('SELECT contact_user_id FROM contacts WHERE user_id = $1', [userId]);
  const lastSeen = status === 'offline' ? new Date().toISOString() : null;
  for (const contact of contacts.rows) {
    io.to(`user:${contact.contact_user_id}`).emit('presence:update', { userId, status, lastSeen });
  }
};

const getIO = () => io;
const sendToUser = (userId, event, data) => { if (io) io.to(`user:${userId}`).emit(event, data); };
const sendToChat = (chatId, event, data) => { if (io) io.to(`chat:${chatId}`).emit(event, data); };

module.exports = { initializeWebSocket, getIO, sendToUser, sendToChat };
