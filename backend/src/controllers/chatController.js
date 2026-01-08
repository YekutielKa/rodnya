const { query, transaction } = require('../config/database');
const { cache, pubsub } = require('../config/redis');
const ApiResponse = require('../utils/response');
const logger = require('../utils/logger');
const { v4: uuidv4 } = require('uuid');

// Get all chats for user
const getChats = async (req, res) => {
  try {
    const { page = 1, limit = 50, archived = false } = req.query;
    const offset = (page - 1) * limit;

    const result = await query(
      `SELECT 
         c.id, c.type, c.name, c.avatar_url, c.created_at,
         cm.is_pinned, cm.is_archived, cm.is_muted, cm.unread_count,
         m.id as last_message_id, m.type as last_message_type, 
         m.content as last_message_content, m.created_at as last_message_at,
         m.sender_id as last_message_sender_id,
         sender.name as last_message_sender_name,
         CASE 
           WHEN c.type = 'direct' THEN (
             SELECT json_build_object('id', u.id, 'name', COALESCE(ct.nickname, u.name), 'avatarUrl', u.avatar_url, 'isOnline', u.is_online)
             FROM chat_members cm2
             JOIN users u ON u.id = cm2.user_id
             LEFT JOIN contacts ct ON ct.user_id = $1 AND ct.contact_user_id = u.id
             WHERE cm2.chat_id = c.id AND cm2.user_id != $1
             LIMIT 1
           )
           ELSE NULL
         END as other_user
       FROM chats c
       JOIN chat_members cm ON cm.chat_id = c.id AND cm.user_id = $1
       LEFT JOIN messages m ON m.id = c.last_message_id
       LEFT JOIN users sender ON sender.id = m.sender_id
       WHERE cm.is_archived = $2
       ORDER BY cm.is_pinned DESC, c.last_message_at DESC NULLS LAST
       LIMIT $3 OFFSET $4`,
      [req.user.id, archived === 'true', limit, offset]
    );

    // Get total count
    const countResult = await query(
      `SELECT COUNT(*) FROM chat_members WHERE user_id = $1 AND is_archived = $2`,
      [req.user.id, archived === 'true']
    );

    const chats = result.rows.map(chat => ({
      id: chat.id,
      type: chat.type,
      name: chat.type === 'direct' ? chat.other_user?.name : chat.name,
      avatarUrl: chat.type === 'direct' ? chat.other_user?.avatarUrl : chat.avatar_url,
      isPinned: chat.is_pinned,
      isArchived: chat.is_archived,
      isMuted: chat.is_muted,
      unreadCount: chat.unread_count,
      otherUser: chat.other_user,
      lastMessage: chat.last_message_id ? {
        id: chat.last_message_id,
        type: chat.last_message_type,
        content: chat.last_message_content,
        senderId: chat.last_message_sender_id,
        senderName: chat.last_message_sender_name,
        createdAt: chat.last_message_at
      } : null,
      createdAt: chat.created_at
    }));

    return ApiResponse.paginated(res, chats, {
      page: parseInt(page),
      limit: parseInt(limit),
      total: parseInt(countResult.rows[0].count)
    });

  } catch (error) {
    logger.error('Get chats error:', error);
    return ApiResponse.serverError(res);
  }
};

// Get or create direct chat
const getOrCreateDirectChat = async (req, res) => {
  try {
    const { userId } = req.body;

    if (userId === req.user.id) {
      return ApiResponse.error(res, 'Cannot create chat with yourself', 400);
    }

    // Check if user exists
    const userCheck = await query('SELECT id FROM users WHERE id = $1', [userId]);
    if (userCheck.rows.length === 0) {
      return ApiResponse.notFound(res, 'User not found');
    }

    // Check if blocked
    const blockCheck = await query(
      `SELECT id FROM contacts 
       WHERE (user_id = $1 AND contact_user_id = $2 AND is_blocked = TRUE)
          OR (user_id = $2 AND contact_user_id = $1 AND is_blocked = TRUE)`,
      [req.user.id, userId]
    );

    if (blockCheck.rows.length > 0) {
      return ApiResponse.forbidden(res, 'Cannot chat with this user');
    }

    // Find existing direct chat
    const existingChat = await query(
      `SELECT c.id FROM chats c
       JOIN chat_members cm1 ON cm1.chat_id = c.id AND cm1.user_id = $1
       JOIN chat_members cm2 ON cm2.chat_id = c.id AND cm2.user_id = $2
       WHERE c.type = 'direct'`,
      [req.user.id, userId]
    );

    if (existingChat.rows.length > 0) {
      return ApiResponse.success(res, { chatId: existingChat.rows[0].id, isNew: false });
    }

    // Create new chat
    const result = await transaction(async (client) => {
      const chatResult = await client.query(
        `INSERT INTO chats (type) VALUES ('direct') RETURNING id`
      );

      const chatId = chatResult.rows[0].id;

      await client.query(
        `INSERT INTO chat_members (chat_id, user_id) VALUES ($1, $2), ($1, $3)`,
        [chatId, req.user.id, userId]
      );

      return chatId;
    });

    return ApiResponse.created(res, { chatId: result, isNew: true });

  } catch (error) {
    logger.error('Get or create direct chat error:', error);
    return ApiResponse.serverError(res);
  }
};

// Create group chat
const createGroupChat = async (req, res) => {
  try {
    const { name, memberIds, avatarUrl } = req.body;

    if (!memberIds || memberIds.length < 1) {
      return ApiResponse.error(res, 'At least one member required', 400);
    }

    // Add current user to members
    const allMembers = [...new Set([req.user.id, ...memberIds])];

    // Verify all users exist
    const usersCheck = await query(
      'SELECT id FROM users WHERE id = ANY($1)',
      [allMembers]
    );

    if (usersCheck.rows.length !== allMembers.length) {
      return ApiResponse.error(res, 'Some users not found', 400);
    }

    const result = await transaction(async (client) => {
      const chatResult = await client.query(
        `INSERT INTO chats (type, name, avatar_url, created_by) 
         VALUES ('group', $1, $2, $3) RETURNING id`,
        [name, avatarUrl, req.user.id]
      );

      const chatId = chatResult.rows[0].id;

      // Add members
      for (const memberId of allMembers) {
        const role = memberId === req.user.id ? 'admin' : 'member';
        await client.query(
          `INSERT INTO chat_members (chat_id, user_id, role) VALUES ($1, $2, $3)`,
          [chatId, memberId, role]
        );
      }

      // Create system message
      await client.query(
        `INSERT INTO messages (chat_id, sender_id, type, content) 
         VALUES ($1, $2, 'system', $3)`,
        [chatId, req.user.id, JSON.stringify({ action: 'group_created', name })]
      );

      return chatId;
    });

    return ApiResponse.created(res, { chatId: result });

  } catch (error) {
    logger.error('Create group chat error:', error);
    return ApiResponse.serverError(res);
  }
};

// Get chat details
const getChatById = async (req, res) => {
  try {
    const { chatId } = req.params;

    // Check membership
    const memberCheck = await query(
      'SELECT id FROM chat_members WHERE chat_id = $1 AND user_id = $2',
      [chatId, req.user.id]
    );

    if (memberCheck.rows.length === 0) {
      return ApiResponse.forbidden(res, 'Not a member of this chat');
    }

    const result = await query(
      `SELECT c.*, 
         (SELECT json_agg(json_build_object(
           'id', u.id, 'name', u.name, 'avatarUrl', u.avatar_url, 
           'isOnline', u.is_online, 'role', cm.role
         ))
         FROM chat_members cm
         JOIN users u ON u.id = cm.user_id
         WHERE cm.chat_id = c.id) as members
       FROM chats c
       WHERE c.id = $1`,
      [chatId]
    );

    if (result.rows.length === 0) {
      return ApiResponse.notFound(res, 'Chat not found');
    }

    const chat = result.rows[0];

    return ApiResponse.success(res, {
      id: chat.id,
      type: chat.type,
      name: chat.name,
      description: chat.description,
      avatarUrl: chat.avatar_url,
      members: chat.members,
      createdBy: chat.created_by,
      createdAt: chat.created_at
    });

  } catch (error) {
    logger.error('Get chat error:', error);
    return ApiResponse.serverError(res);
  }
};

// Update chat (group only)
const updateChat = async (req, res) => {
  try {
    const { chatId } = req.params;
    const { name, description, avatarUrl } = req.body;

    // Check admin
    const adminCheck = await query(
      `SELECT cm.role, c.type FROM chat_members cm
       JOIN chats c ON c.id = cm.chat_id
       WHERE cm.chat_id = $1 AND cm.user_id = $2`,
      [chatId, req.user.id]
    );

    if (adminCheck.rows.length === 0) {
      return ApiResponse.forbidden(res, 'Not a member');
    }

    if (adminCheck.rows[0].type !== 'group') {
      return ApiResponse.error(res, 'Cannot update direct chat', 400);
    }

    if (adminCheck.rows[0].role !== 'admin') {
      return ApiResponse.forbidden(res, 'Admin only');
    }

    const updates = [];
    const values = [];
    let paramCount = 1;

    if (name !== undefined) {
      updates.push(`name = $${paramCount++}`);
      values.push(name);
    }
    if (description !== undefined) {
      updates.push(`description = $${paramCount++}`);
      values.push(description);
    }
    if (avatarUrl !== undefined) {
      updates.push(`avatar_url = $${paramCount++}`);
      values.push(avatarUrl);
    }

    if (updates.length === 0) {
      return ApiResponse.error(res, 'No fields to update', 400);
    }

    values.push(chatId);

    await query(
      `UPDATE chats SET ${updates.join(', ')} WHERE id = $${paramCount}`,
      values
    );

    return ApiResponse.success(res, null, 'Chat updated');

  } catch (error) {
    logger.error('Update chat error:', error);
    return ApiResponse.serverError(res);
  }
};

// Add member to group
const addMember = async (req, res) => {
  try {
    const { chatId } = req.params;
    const { userId } = req.body;

    // Check admin
    const adminCheck = await query(
      `SELECT cm.role, c.type FROM chat_members cm
       JOIN chats c ON c.id = cm.chat_id
       WHERE cm.chat_id = $1 AND cm.user_id = $2`,
      [chatId, req.user.id]
    );

    if (adminCheck.rows.length === 0 || adminCheck.rows[0].type !== 'group') {
      return ApiResponse.forbidden(res);
    }

    if (adminCheck.rows[0].role !== 'admin') {
      return ApiResponse.forbidden(res, 'Admin only');
    }

    // Check user exists
    const userCheck = await query('SELECT name FROM users WHERE id = $1', [userId]);
    if (userCheck.rows.length === 0) {
      return ApiResponse.notFound(res, 'User not found');
    }

    // Add member
    await query(
      `INSERT INTO chat_members (chat_id, user_id) VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [chatId, userId]
    );

    // System message
    await query(
      `INSERT INTO messages (chat_id, sender_id, type, content) VALUES ($1, $2, 'system', $3)`,
      [chatId, req.user.id, JSON.stringify({ action: 'member_added', userId, userName: userCheck.rows[0].name })]
    );

    return ApiResponse.success(res, null, 'Member added');

  } catch (error) {
    logger.error('Add member error:', error);
    return ApiResponse.serverError(res);
  }
};

// Remove member from group
const removeMember = async (req, res) => {
  try {
    const { chatId, userId } = req.params;

    // Check admin or self-removal
    const memberCheck = await query(
      `SELECT cm.role, c.type, c.created_by FROM chat_members cm
       JOIN chats c ON c.id = cm.chat_id
       WHERE cm.chat_id = $1 AND cm.user_id = $2`,
      [chatId, req.user.id]
    );

    if (memberCheck.rows.length === 0 || memberCheck.rows[0].type !== 'group') {
      return ApiResponse.forbidden(res);
    }

    const isAdmin = memberCheck.rows[0].role === 'admin';
    const isSelf = userId === req.user.id;

    if (!isAdmin && !isSelf) {
      return ApiResponse.forbidden(res, 'Admin only');
    }

    // Cannot remove creator
    if (userId === memberCheck.rows[0].created_by && !isSelf) {
      return ApiResponse.error(res, 'Cannot remove group creator', 400);
    }

    // Get user name for system message
    const userInfo = await query('SELECT name FROM users WHERE id = $1', [userId]);

    await query(
      'DELETE FROM chat_members WHERE chat_id = $1 AND user_id = $2',
      [chatId, userId]
    );

    // System message
    const action = isSelf ? 'member_left' : 'member_removed';
    await query(
      `INSERT INTO messages (chat_id, sender_id, type, content) VALUES ($1, $2, 'system', $3)`,
      [chatId, req.user.id, JSON.stringify({ action, userId, userName: userInfo.rows[0]?.name })]
    );

    return ApiResponse.success(res, null, isSelf ? 'Left group' : 'Member removed');

  } catch (error) {
    logger.error('Remove member error:', error);
    return ApiResponse.serverError(res);
  }
};

// Update chat settings (mute, pin, archive)
const updateChatSettings = async (req, res) => {
  try {
    const { chatId } = req.params;
    const { isPinned, isMuted, isArchived, mutedUntil } = req.body;

    const updates = [];
    const values = [];
    let paramCount = 1;

    if (isPinned !== undefined) {
      updates.push(`is_pinned = $${paramCount++}`);
      values.push(isPinned);
    }
    if (isMuted !== undefined) {
      updates.push(`is_muted = $${paramCount++}`);
      values.push(isMuted);
    }
    if (isArchived !== undefined) {
      updates.push(`is_archived = $${paramCount++}`);
      values.push(isArchived);
    }
    if (mutedUntil !== undefined) {
      updates.push(`muted_until = $${paramCount++}`);
      values.push(mutedUntil);
    }

    if (updates.length === 0) {
      return ApiResponse.error(res, 'No settings to update', 400);
    }

    values.push(chatId, req.user.id);

    await query(
      `UPDATE chat_members SET ${updates.join(', ')} 
       WHERE chat_id = $${paramCount++} AND user_id = $${paramCount}`,
      values
    );

    return ApiResponse.success(res, null, 'Settings updated');

  } catch (error) {
    logger.error('Update chat settings error:', error);
    return ApiResponse.serverError(res);
  }
};

// Mark chat as read
const markAsRead = async (req, res) => {
  try {
    const { chatId } = req.params;
    const { messageId } = req.body;

    await query(
      `UPDATE chat_members 
       SET last_read_at = NOW(), last_read_message_id = $1, unread_count = 0
       WHERE chat_id = $2 AND user_id = $3`,
      [messageId, chatId, req.user.id]
    );

    // Update message status
    if (messageId) {
      await query(
        `UPDATE message_status SET status = 'read', status_at = NOW()
         WHERE message_id = $1 AND user_id = $2`,
        [messageId, req.user.id]
      );
    }

    return ApiResponse.success(res, null, 'Marked as read');

  } catch (error) {
    logger.error('Mark as read error:', error);
    return ApiResponse.serverError(res);
  }
};

module.exports = {
  getChats,
  getOrCreateDirectChat,
  createGroupChat,
  getChatById,
  updateChat,
  addMember,
  removeMember,
  updateChatSettings,
  markAsRead
};
