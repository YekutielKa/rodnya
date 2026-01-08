const { query } = require('../config/database');
const logger = require('../config/logger');
const ApiResponse = require('../utils/apiResponse');
const { getIO } = require('../config/socket');

// Get messages with pagination
const getMessages = async (req, res) => {
  try {
    const { chatId } = req.params;
    const { before, after, limit = 50 } = req.query;

    // Check membership
    const memberCheck = await query(
      'SELECT id FROM chat_members WHERE chat_id = $1 AND user_id = $2',
      [chatId, req.user.id]
    );

    if (memberCheck.rows.length === 0) {
      return ApiResponse.forbidden(res, 'Not a member of this chat');
    }

    let queryText = `
      SELECT m.*,
        u.name as sender_name,
        u.avatar_url as sender_avatar,
        r.id as reply_id,
        r.content as reply_content,
        r.type as reply_type,
        ru.name as reply_sender_name
      FROM messages m
      JOIN users u ON u.id = m.sender_id
      LEFT JOIN messages r ON r.id = m.reply_to_id
      LEFT JOIN users ru ON ru.id = r.sender_id
      WHERE m.chat_id = $1
    `;

    const params = [chatId];
    let paramCount = 1;

    if (before) {
      paramCount++;
      queryText += ` AND m.created_at < $${paramCount}`;
      params.push(before);
    }

    if (after) {
      paramCount++;
      queryText += ` AND m.created_at > $${paramCount}`;
      params.push(after);
    }

    paramCount++;
    queryText += ` ORDER BY m.created_at DESC LIMIT $${paramCount}`;
    params.push(parseInt(limit));

    const result = await query(queryText, params);

    // Format messages with sender info
    const messages = result.rows.map(m => ({
      id: m.id,
      chatId: m.chat_id,
      type: m.type,
      content: m.content,
      mediaUrl: m.media_url,
      thumbnailUrl: m.thumbnail_url,
      fileName: m.file_name,
      fileSize: m.file_size,
      duration: m.duration,
      metadata: m.metadata,
      sender: {
        id: m.sender_id,
        name: m.sender_name,
        avatarUrl: m.sender_avatar
      },
      replyTo: m.reply_id ? {
        id: m.reply_id,
        content: m.reply_content,
        type: m.reply_type,
        senderName: m.reply_sender_name
      } : null,
      readBy: m.read_by || [],
      status: m.status || 'sent',
      isDeleted: m.is_deleted || false,
      isEdited: m.is_edited || false,
      editedAt: m.edited_at,
      createdAt: m.created_at
    }));

    return ApiResponse.success(res, messages);
  } catch (error) {
    logger.error('Get messages error:', error);
    return ApiResponse.serverError(res);
  }
};

// Send message
const sendMessage = async (req, res) => {
  try {
    const { chatId } = req.params;
    const { 
      type = 'text', 
      content, 
      mediaUrl,
      thumbnailUrl,
      fileName,
      fileSize,
      duration,
      metadata, 
      replyToId 
    } = req.body;

    // Check membership
    const memberCheck = await query(
      `SELECT cm.id, c.type as chat_type FROM chat_members cm
       JOIN chats c ON c.id = cm.chat_id
       WHERE cm.chat_id = $1 AND cm.user_id = $2`,
      [chatId, req.user.id]
    );

    if (memberCheck.rows.length === 0) {
      return ApiResponse.forbidden(res, 'Not a member of this chat');
    }

    // Create message
    const result = await query(
      `INSERT INTO messages (
        chat_id, sender_id, type, content, 
        media_url, thumbnail_url, file_name, file_size, duration,
        metadata, reply_to_id
      )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [
        chatId, req.user.id, type, content,
        mediaUrl, thumbnailUrl, fileName, fileSize, duration,
        metadata || {}, replyToId
      ]
    );

    const messageRow = result.rows[0];

    // Get sender info
    const userResult = await query(
      'SELECT name, avatar_url FROM users WHERE id = $1',
      [req.user.id]
    );
    const sender = userResult.rows[0];

    // Get reply info if exists
    let replyTo = null;
    if (replyToId) {
      const replyResult = await query(
        `SELECT m.id, m.content, m.type, u.name as sender_name
         FROM messages m
         JOIN users u ON u.id = m.sender_id
         WHERE m.id = $1`,
        [replyToId]
      );
      if (replyResult.rows.length > 0) {
        const r = replyResult.rows[0];
        replyTo = {
          id: r.id,
          content: r.content,
          type: r.type,
          senderName: r.sender_name
        };
      }
    }

    // Format response with full sender info
    const message = {
      id: messageRow.id,
      chatId: messageRow.chat_id,
      type: messageRow.type,
      content: messageRow.content,
      mediaUrl: messageRow.media_url,
      thumbnailUrl: messageRow.thumbnail_url,
      fileName: messageRow.file_name,
      fileSize: messageRow.file_size,
      duration: messageRow.duration,
      metadata: messageRow.metadata,
      sender: {
        id: req.user.id,
        name: sender.name,
        avatarUrl: sender.avatar_url
      },
      replyTo: replyTo,
      readBy: [],
      status: 'sent',
      isDeleted: false,
      isEdited: false,
      createdAt: messageRow.created_at
    };

    // Update chat's updated_at
    await query(
      'UPDATE chats SET updated_at = NOW() WHERE id = $1',
      [chatId]
    );

    // Get chat members for socket notification
    const members = await query(
      'SELECT user_id FROM chat_members WHERE chat_id = $1 AND user_id != $2',
      [chatId, req.user.id]
    );

    // Emit to socket
    const io = getIO();
    if (io) {
      members.rows.forEach(member => {
        io.to(`user:${member.user_id}`).emit('message:new', {
          chatId,
          message
        });
      });
    }

    return ApiResponse.created(res, message);
  } catch (error) {
    logger.error('Send message error:', error);
    return ApiResponse.serverError(res);
  }
};

// Edit message
const editMessage = async (req, res) => {
  try {
    const { messageId } = req.params;
    const { content } = req.body;

    // Check ownership
    const messageCheck = await query(
      'SELECT * FROM messages WHERE id = $1 AND sender_id = $2',
      [messageId, req.user.id]
    );

    if (messageCheck.rows.length === 0) {
      return ApiResponse.forbidden(res, 'Cannot edit this message');
    }

    const result = await query(
      `UPDATE messages 
       SET content = $1, is_edited = true, edited_at = NOW()
       WHERE id = $2
       RETURNING *`,
      [content, messageId]
    );

    const messageRow = result.rows[0];

    // Get sender info
    const userResult = await query(
      'SELECT name, avatar_url FROM users WHERE id = $1',
      [req.user.id]
    );
    const sender = userResult.rows[0];

    const message = {
      id: messageRow.id,
      chatId: messageRow.chat_id,
      type: messageRow.type,
      content: messageRow.content,
      sender: {
        id: req.user.id,
        name: sender.name,
        avatarUrl: sender.avatar_url
      },
      isEdited: true,
      editedAt: messageRow.edited_at,
      createdAt: messageRow.created_at
    };

    // Emit to socket
    const io = getIO();
    if (io) {
      io.to(`chat:${messageRow.chat_id}`).emit('message:updated', message);
    }

    return ApiResponse.success(res, message);
  } catch (error) {
    logger.error('Edit message error:', error);
    return ApiResponse.serverError(res);
  }
};

// Delete message
const deleteMessage = async (req, res) => {
  try {
    const { messageId, chatId } = req.params;

    // Check ownership or admin
    const messageCheck = await query(
      `SELECT m.*, cm.role 
       FROM messages m
       JOIN chat_members cm ON cm.chat_id = m.chat_id AND cm.user_id = $1
       WHERE m.id = $2`,
      [req.user.id, messageId]
    );

    if (messageCheck.rows.length === 0) {
      return ApiResponse.notFound(res, 'Message not found');
    }

    const message = messageCheck.rows[0];
    
    // Only sender or admin can delete
    if (message.sender_id !== req.user.id && message.role !== 'admin') {
      return ApiResponse.forbidden(res, 'Cannot delete this message');
    }

    await query(
      `UPDATE messages 
       SET is_deleted = true, content = 'Сообщение удалено'
       WHERE id = $1`,
      [messageId]
    );

    // Emit to socket
    const io = getIO();
    if (io) {
      io.to(`chat:${message.chat_id}`).emit('message:deleted', {
        messageId,
        chatId: message.chat_id
      });
    }

    return ApiResponse.success(res, { deleted: true });
  } catch (error) {
    logger.error('Delete message error:', error);
    return ApiResponse.serverError(res);
  }
};

// Mark message as read
const markAsRead = async (req, res) => {
  try {
    const { messageId } = req.params;

    await query(
      `UPDATE messages 
       SET read_by = array_append(read_by, $1)
       WHERE id = $2 AND NOT ($1 = ANY(read_by))`,
      [req.user.id, messageId]
    );

    return ApiResponse.success(res, { read: true });
  } catch (error) {
    logger.error('Mark as read error:', error);
    return ApiResponse.serverError(res);
  }
};

// Update message status (delivered, read)
const updateMessageStatus = async (req, res) => {
  try {
    const { messageId } = req.params;
    const { status } = req.body;

    if (!['delivered', 'read'].includes(status)) {
      return ApiResponse.badRequest(res, 'Invalid status');
    }

    const result = await query(
      `UPDATE messages SET status = $1 WHERE id = $2 RETURNING *`,
      [status, messageId]
    );

    if (result.rows.length === 0) {
      return ApiResponse.notFound(res, 'Message not found');
    }

    return ApiResponse.success(res, { status });
  } catch (error) {
    logger.error('Update message status error:', error);
    return ApiResponse.serverError(res);
  }
};

// Search messages in chat
const searchMessages = async (req, res) => {
  try {
    const { chatId } = req.params;
    const { q, limit = 20 } = req.query;

    if (!q || q.length < 2) {
      return ApiResponse.badRequest(res, 'Search query too short');
    }

    // Check membership
    const memberCheck = await query(
      'SELECT id FROM chat_members WHERE chat_id = $1 AND user_id = $2',
      [chatId, req.user.id]
    );

    if (memberCheck.rows.length === 0) {
      return ApiResponse.forbidden(res, 'Not a member of this chat');
    }

    const result = await query(
      `SELECT m.*, u.name as sender_name, u.avatar_url as sender_avatar
       FROM messages m
       JOIN users u ON u.id = m.sender_id
       WHERE m.chat_id = $1 
         AND m.type = 'text'
         AND m.content ILIKE $2
         AND m.is_deleted = false
       ORDER BY m.created_at DESC
       LIMIT $3`,
      [chatId, `%${q}%`, parseInt(limit)]
    );

    const messages = result.rows.map(m => ({
      id: m.id,
      chatId: m.chat_id,
      type: m.type,
      content: m.content,
      sender: {
        id: m.sender_id,
        name: m.sender_name,
        avatarUrl: m.sender_avatar
      },
      createdAt: m.created_at
    }));

    return ApiResponse.success(res, messages);
  } catch (error) {
    logger.error('Search messages error:', error);
    return ApiResponse.serverError(res);
  }
};

module.exports = {
  getMessages,
  sendMessage,
  editMessage,
  deleteMessage,
  markAsRead,
  updateMessageStatus,
  searchMessages
};
