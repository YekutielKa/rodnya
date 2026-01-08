const { query, transaction } = require('../config/database');
const { pubsub } = require('../config/redis');
const ApiResponse = require('../utils/response');
const logger = require('../utils/logger');

// Get messages for chat
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
        u.name as sender_name, u.avatar_url as sender_avatar,
        rm.content as reply_content, rm.type as reply_type,
        ru.name as reply_sender_name
      FROM messages m
      JOIN users u ON u.id = m.sender_id
      LEFT JOIN messages rm ON rm.id = m.reply_to_id
      LEFT JOIN users ru ON ru.id = rm.sender_id
      WHERE m.chat_id = $1 AND m.is_deleted = FALSE
    `;
    
    const params = [chatId];
    let paramCount = 2;

    if (before) {
      queryText += ` AND m.created_at < $${paramCount++}`;
      params.push(before);
    }
    if (after) {
      queryText += ` AND m.created_at > $${paramCount++}`;
      params.push(after);
    }

    queryText += ` ORDER BY m.created_at DESC LIMIT $${paramCount}`;
    params.push(parseInt(limit));

    const result = await query(queryText, params);

    const messages = result.rows.map(m => ({
      id: m.id,
      chatId: m.chat_id,
      type: m.type,
      content: m.content,
      metadata: m.metadata,
      sender: {
        id: m.sender_id,
        name: m.sender_name,
        avatarUrl: m.sender_avatar
      },
      replyTo: m.reply_to_id ? {
        id: m.reply_to_id,
        content: m.reply_content,
        type: m.reply_type,
        senderName: m.reply_sender_name
      } : null,
      isEdited: m.is_edited,
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
    const { type = 'text', content, metadata, replyToId } = req.body;

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
      `INSERT INTO messages (chat_id, sender_id, type, content, metadata, reply_to_id)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [chatId, req.user.id, type, content, metadata || {}, replyToId]
    );

    const message = result.rows[0];

    // Get chat members for delivery status
    const members = await query(
      'SELECT user_id FROM chat_members WHERE chat_id = $1 AND user_id != $2',
      [chatId, req.user.id]
    );

    // Create delivery status for each member
    for (const member of members.rows) {
      await query(
        `INSERT INTO message_status (message_id, user_id, status) VALUES ($1, $2, 'sent')`,
        [message.id, member.user_id]
      );
    }

    // Publish to Redis for real-time delivery
    await pubsub.publish(`chat:${chatId}`, {
      type: 'new_message',
      message: {
        id: message.id,
        chatId: message.chat_id,
        type: message.type,
        content: message.content,
        metadata: message.metadata,
        sender: {
          id: req.user.id,
          name: req.user.name,
          avatarUrl: req.user.avatar_url
        },
        replyToId: message.reply_to_id,
        createdAt: message.created_at
      }
    });

    return ApiResponse.created(res, {
      id: message.id,
      chatId: message.chat_id,
      type: message.type,
      content: message.content,
      metadata: message.metadata,
      createdAt: message.created_at
    });

  } catch (error) {
    logger.error('Send message error:', error);
    return ApiResponse.serverError(res);
  }
};

// Edit message
const editMessage = async (req, res) => {
  try {
    const { chatId, messageId } = req.params;
    const { content } = req.body;

    // Check ownership
    const messageCheck = await query(
      'SELECT id FROM messages WHERE id = $1 AND chat_id = $2 AND sender_id = $3 AND is_deleted = FALSE',
      [messageId, chatId, req.user.id]
    );

    if (messageCheck.rows.length === 0) {
      return ApiResponse.notFound(res, 'Message not found or not yours');
    }

    await query(
      `UPDATE messages SET content = $1, is_edited = TRUE, edited_at = NOW() WHERE id = $2`,
      [content, messageId]
    );

    // Publish edit event
    await pubsub.publish(`chat:${chatId}`, {
      type: 'message_edited',
      messageId,
      content,
      editedAt: new Date().toISOString()
    });

    return ApiResponse.success(res, null, 'Message edited');

  } catch (error) {
    logger.error('Edit message error:', error);
    return ApiResponse.serverError(res);
  }
};

// Delete message
const deleteMessage = async (req, res) => {
  try {
    const { chatId, messageId } = req.params;
    const { forEveryone = false } = req.body;

    // Check ownership or admin
    const messageCheck = await query(
      `SELECT m.sender_id, cm.role FROM messages m
       JOIN chat_members cm ON cm.chat_id = m.chat_id AND cm.user_id = $3
       WHERE m.id = $1 AND m.chat_id = $2`,
      [messageId, chatId, req.user.id]
    );

    if (messageCheck.rows.length === 0) {
      return ApiResponse.notFound(res, 'Message not found');
    }

    const isOwner = messageCheck.rows[0].sender_id === req.user.id;
    const isAdmin = messageCheck.rows[0].role === 'admin';

    if (!isOwner && !isAdmin) {
      return ApiResponse.forbidden(res, 'Cannot delete this message');
    }

    if (forEveryone && (isOwner || isAdmin)) {
      await query(
        `UPDATE messages SET is_deleted = TRUE, deleted_at = NOW(), content = NULL WHERE id = $1`,
        [messageId]
      );

      await pubsub.publish(`chat:${chatId}`, {
        type: 'message_deleted',
        messageId
      });
    }

    return ApiResponse.success(res, null, 'Message deleted');

  } catch (error) {
    logger.error('Delete message error:', error);
    return ApiResponse.serverError(res);
  }
};

// Update message status (delivered/read)
const updateMessageStatus = async (req, res) => {
  try {
    const { chatId, messageId } = req.params;
    const { status } = req.body;

    if (!['delivered', 'read'].includes(status)) {
      return ApiResponse.error(res, 'Invalid status', 400);
    }

    await query(
      `UPDATE message_status SET status = $1, status_at = NOW() 
       WHERE message_id = $2 AND user_id = $3`,
      [status, messageId, req.user.id]
    );

    // Get message sender
    const message = await query(
      'SELECT sender_id FROM messages WHERE id = $1',
      [messageId]
    );

    if (message.rows.length > 0) {
      await pubsub.publish(`user:${message.rows[0].sender_id}`, {
        type: 'message_status',
        messageId,
        status,
        userId: req.user.id
      });
    }

    return ApiResponse.success(res);

  } catch (error) {
    logger.error('Update message status error:', error);
    return ApiResponse.serverError(res);
  }
};

// Search messages
const searchMessages = async (req, res) => {
  try {
    const { q, chatId, limit = 20, offset = 0 } = req.query;

    if (!q || q.length < 2) {
      return ApiResponse.error(res, 'Search query too short', 400);
    }

    let queryText = `
      SELECT m.id, m.chat_id, m.type, m.content, m.created_at,
        u.name as sender_name,
        c.name as chat_name, c.type as chat_type
      FROM messages m
      JOIN users u ON u.id = m.sender_id
      JOIN chats c ON c.id = m.chat_id
      JOIN chat_members cm ON cm.chat_id = m.chat_id AND cm.user_id = $1
      WHERE m.is_deleted = FALSE AND m.content ILIKE $2
    `;

    const params = [req.user.id, `%${q}%`];
    let paramCount = 3;

    if (chatId) {
      queryText += ` AND m.chat_id = $${paramCount++}`;
      params.push(chatId);
    }

    queryText += ` ORDER BY m.created_at DESC LIMIT $${paramCount++} OFFSET $${paramCount}`;
    params.push(parseInt(limit), parseInt(offset));

    const result = await query(queryText, params);

    return ApiResponse.success(res, result.rows.map(m => ({
      id: m.id,
      chatId: m.chat_id,
      chatName: m.chat_name,
      chatType: m.chat_type,
      type: m.type,
      content: m.content,
      senderName: m.sender_name,
      createdAt: m.created_at
    })));

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
  updateMessageStatus,
  searchMessages
};
