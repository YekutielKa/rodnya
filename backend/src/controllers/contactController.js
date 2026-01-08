const { query, transaction } = require('../config/database');
const { hashPhone } = require('../utils/jwt');
const ApiResponse = require('../utils/response');
const logger = require('../utils/logger');

// Get all contacts
const getContacts = async (req, res) => {
  try {
    const { favorites, blocked } = req.query;

    let queryText = `
      SELECT c.*, u.name as user_name, u.avatar_url, u.status, u.is_online, u.last_seen
      FROM contacts c
      JOIN users u ON u.id = c.contact_user_id
      WHERE c.user_id = $1
    `;

    const params = [req.user.id];
    let paramCount = 2;

    if (favorites === 'true') {
      queryText += ` AND c.is_favorite = TRUE`;
    }
    if (blocked === 'true') {
      queryText += ` AND c.is_blocked = TRUE`;
    } else {
      queryText += ` AND c.is_blocked = FALSE`;
    }

    queryText += ` ORDER BY c.is_favorite DESC, COALESCE(c.nickname, u.name) ASC`;

    const result = await query(queryText, params);

    const contacts = result.rows.map(c => ({
      id: c.id,
      userId: c.contact_user_id,
      name: c.nickname || c.user_name,
      originalName: c.user_name,
      avatarUrl: c.avatar_url,
      status: c.status,
      isOnline: c.is_online,
      lastSeen: c.last_seen,
      isFavorite: c.is_favorite,
      isBlocked: c.is_blocked,
      createdAt: c.created_at
    }));

    return ApiResponse.success(res, contacts);

  } catch (error) {
    logger.error('Get contacts error:', error);
    return ApiResponse.serverError(res);
  }
};

// Add contact
const addContact = async (req, res) => {
  try {
    const { userId, nickname } = req.body;

    if (userId === req.user.id) {
      return ApiResponse.error(res, 'Cannot add yourself', 400);
    }

    // Check if user exists
    const userCheck = await query('SELECT id, name FROM users WHERE id = $1', [userId]);
    if (userCheck.rows.length === 0) {
      return ApiResponse.notFound(res, 'User not found');
    }

    // Add contact
    const result = await query(
      `INSERT INTO contacts (user_id, contact_user_id, nickname)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, contact_user_id) 
       DO UPDATE SET nickname = COALESCE($3, contacts.nickname)
       RETURNING *`,
      [req.user.id, userId, nickname]
    );

    return ApiResponse.created(res, {
      id: result.rows[0].id,
      userId,
      name: nickname || userCheck.rows[0].name
    });

  } catch (error) {
    logger.error('Add contact error:', error);
    return ApiResponse.serverError(res);
  }
};

// Sync contacts from phone (by phone numbers)
const syncContacts = async (req, res) => {
  try {
    const { phones } = req.body;

    if (!phones || !Array.isArray(phones) || phones.length === 0) {
      return ApiResponse.error(res, 'No phones provided', 400);
    }

    // Hash all phones
    const phoneHashes = phones.map(p => hashPhone(p.replace(/\D/g, '')));

    // Find registered users
    const result = await query(
      `SELECT id, phone, name, avatar_url FROM users 
       WHERE phone_hash = ANY($1) AND id != $2`,
      [phoneHashes, req.user.id]
    );

    // Return found users (not adding as contacts automatically)
    return ApiResponse.success(res, {
      found: result.rows.map(u => ({
        id: u.id,
        phone: u.phone,
        name: u.name,
        avatarUrl: u.avatar_url
      })),
      count: result.rows.length
    });

  } catch (error) {
    logger.error('Sync contacts error:', error);
    return ApiResponse.serverError(res);
  }
};

// Update contact
const updateContact = async (req, res) => {
  try {
    const { contactId } = req.params;
    const { nickname, isFavorite } = req.body;

    const updates = [];
    const values = [];
    let paramCount = 1;

    if (nickname !== undefined) {
      updates.push(`nickname = $${paramCount++}`);
      values.push(nickname || null);
    }
    if (isFavorite !== undefined) {
      updates.push(`is_favorite = $${paramCount++}`);
      values.push(isFavorite);
    }

    if (updates.length === 0) {
      return ApiResponse.error(res, 'No fields to update', 400);
    }

    values.push(contactId, req.user.id);

    const result = await query(
      `UPDATE contacts SET ${updates.join(', ')} 
       WHERE id = $${paramCount++} AND user_id = $${paramCount}
       RETURNING *`,
      values
    );

    if (result.rows.length === 0) {
      return ApiResponse.notFound(res, 'Contact not found');
    }

    return ApiResponse.success(res, result.rows[0]);

  } catch (error) {
    logger.error('Update contact error:', error);
    return ApiResponse.serverError(res);
  }
};

// Delete contact
const deleteContact = async (req, res) => {
  try {
    const { contactId } = req.params;

    const result = await query(
      'DELETE FROM contacts WHERE id = $1 AND user_id = $2 RETURNING id',
      [contactId, req.user.id]
    );

    if (result.rows.length === 0) {
      return ApiResponse.notFound(res, 'Contact not found');
    }

    return ApiResponse.success(res, null, 'Contact deleted');

  } catch (error) {
    logger.error('Delete contact error:', error);
    return ApiResponse.serverError(res);
  }
};

// Block user
const blockUser = async (req, res) => {
  try {
    const { userId } = req.params;

    // Upsert contact with blocked status
    await query(
      `INSERT INTO contacts (user_id, contact_user_id, is_blocked)
       VALUES ($1, $2, TRUE)
       ON CONFLICT (user_id, contact_user_id) 
       DO UPDATE SET is_blocked = TRUE`,
      [req.user.id, userId]
    );

    return ApiResponse.success(res, null, 'User blocked');

  } catch (error) {
    logger.error('Block user error:', error);
    return ApiResponse.serverError(res);
  }
};

// Unblock user
const unblockUser = async (req, res) => {
  try {
    const { userId } = req.params;

    await query(
      `UPDATE contacts SET is_blocked = FALSE 
       WHERE user_id = $1 AND contact_user_id = $2`,
      [req.user.id, userId]
    );

    return ApiResponse.success(res, null, 'User unblocked');

  } catch (error) {
    logger.error('Unblock user error:', error);
    return ApiResponse.serverError(res);
  }
};

// Get blocked users
const getBlockedUsers = async (req, res) => {
  try {
    const result = await query(
      `SELECT c.contact_user_id as id, u.name, u.avatar_url, c.created_at as blocked_at
       FROM contacts c
       JOIN users u ON u.id = c.contact_user_id
       WHERE c.user_id = $1 AND c.is_blocked = TRUE`,
      [req.user.id]
    );

    return ApiResponse.success(res, result.rows);

  } catch (error) {
    logger.error('Get blocked users error:', error);
    return ApiResponse.serverError(res);
  }
};

module.exports = {
  getContacts,
  addContact,
  syncContacts,
  updateContact,
  deleteContact,
  blockUser,
  unblockUser,
  getBlockedUsers
};
