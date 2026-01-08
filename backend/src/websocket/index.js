const { Server } = require('socket.io');
const { verifyAccessToken } = require('../utils/jwt');
const { query } = require('../config/database');
const { cache, pubsub } = require('../config/redis');
const logger = require('../utils/logger');

let io = null;

const initializeWebSocket = (httpServer) => {
  io = new Server(httpServer, {
    cors: {
      origin: process.env.CORS_ORIGINS?.split(',') || '*',
      methods: ['GET', 'POST'],
      credentials: true
    },
    pingTimeout: 60000,
    pingInterval: 25000
  });

  // Authentication middleware
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];
      
      if (!token) {
        return next(new Error('Authentication required'));
      }

      const decoded = verifyAccessToken(token);
      if (!decoded) {
        return next(new Error('Invalid token'));
      }

      // Get user
      const result = await query(
        'SELECT id, name, avatar_url FROM users WHERE id = $1',
        [decoded.userId]
      );

      if (result.rows.length === 0) {
        return next(new Error('User not found'));
      }

      socket.user = result.rows[0];
      socket.deviceId = decoded.deviceId;
      next();
    } catch (error) {
      logger.error('Socket auth error:', error);
      next(new Error('Authentication failed'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.user.id;
    logger.info(`User connected: ${userId}`);

    // Join user's personal room
    socket.join(`user:${userId}`);

    // Update online status
    await query('UPDATE users SET is_online = TRUE, last_seen = NOW() WHERE id = $1', [userId]);
    await cache.set(`online:${userId}`, { socketId: socket.id }, 3600);

    // Get user's chats and join rooms
    const chats = await query(
      'SELECT chat_id FROM chat_members WHERE user_id = $1',
      [userId]
    );

    for (const chat of chats.rows) {
      socket.join(`chat:${chat.chat_id}`);
    }

    // Subscribe to Redis channels
    await pubsub.subscribe(`user:${userId}`, (message) => {
      socket.emit(message.type, message);
    });

    // Handle typing
    socket.on('typing:start', async (data) => {
      const { chatId } = data;
      socket.to(`chat:${chatId}`).emit('typing:start', {
        chatId,
        userId,
        userName: socket.user.name
      });
    });

    socket.on('typing:stop', async (data) => {
      const { chatId } = data;
      socket.to(`chat:${chatId}`).emit('typing:stop', {
        chatId,
        userId
      });
    });

    // Handle message read
    socket.on('message:read', async (data) => {
      const { chatId, messageId } = data;
      
      await query(
        `UPDATE chat_members SET last_read_at = NOW(), last_read_message_id = $1, unread_count = 0
         WHERE chat_id = $2 AND user_id = $3`,
        [messageId, chatId, userId]
      );

      await query(
        `UPDATE message_status SET status = 'read', status_at = NOW()
         WHERE message_id = $1 AND user_id = $2`,
        [messageId, userId]
      );

      // Notify sender
      const message = await query('SELECT sender_id FROM messages WHERE id = $1', [messageId]);
      if (message.rows.length > 0) {
        io.to(`user:${message.rows[0].sender_id}`).emit('message:status', {
          messageId,
          status: 'read',
          userId,
          chatId
        });
      }
    });

    // Handle presence
    socket.on('presence:update', async (data) => {
      const { status } = data; // 'online', 'away', 'busy'
      await cache.set(`presence:${userId}`, { status, updatedAt: Date.now() }, 300);
      
      // Notify contacts
      const contacts = await query(
        'SELECT contact_user_id FROM contacts WHERE user_id = $1',
        [userId]
      );
      
      for (const contact of contacts.rows) {
        io.to(`user:${contact.contact_user_id}`).emit('presence:update', {
          userId,
          status
        });
      }
    });

    // Handle WebRTC signaling
    socket.on('call:signal', async (data) => {
      const { callId, targetUserId, signal } = data;
      io.to(`user:${targetUserId}`).emit('call:signal', {
        callId,
        fromUserId: userId,
        signal
      });
    });

    socket.on('call:ice-candidate', async (data) => {
      const { callId, targetUserId, candidate } = data;
      io.to(`user:${targetUserId}`).emit('call:ice-candidate', {
        callId,
        fromUserId: userId,
        candidate
      });
    });

    // Handle disconnect
    socket.on('disconnect', async () => {
      logger.info(`User disconnected: ${userId}`);

      // Check if user has other active sockets
      const sockets = await io.in(`user:${userId}`).fetchSockets();
      
      if (sockets.length === 0) {
        // No more connections, set offline
        await query(
          'UPDATE users SET is_online = FALSE, last_seen = NOW() WHERE id = $1',
          [userId]
        );
        await cache.del(`online:${userId}`);

        // Notify contacts
        const contacts = await query(
          'SELECT contact_user_id FROM contacts WHERE user_id = $1',
          [userId]
        );
        
        for (const contact of contacts.rows) {
          io.to(`user:${contact.contact_user_id}`).emit('presence:update', {
            userId,
            status: 'offline',
            lastSeen: new Date().toISOString()
          });
        }
      }
    });
  });

  return io;
};

const getIO = () => io;

// Utility function to send to specific user
const sendToUser = (userId, event, data) => {
  if (io) {
    io.to(`user:${userId}`).emit(event, data);
  }
};

// Utility function to send to chat
const sendToChat = (chatId, event, data) => {
  if (io) {
    io.to(`chat:${chatId}`).emit(event, data);
  }
};

module.exports = {
  initializeWebSocket,
  getIO,
  sendToUser,
  sendToChat
};
