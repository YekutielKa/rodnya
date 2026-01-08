const { query } = require('../config/database');
const { cache } = require('../config/redis');
const ApiResponse = require('../utils/response');
const logger = require('../utils/logger');

// Get all users (for family app)
const getAllUsers = async (req, res) => {
  try {
    const result = await query(
      `SELECT id, phone, name, avatar_url, status, is_online, last_seen 
       FROM users 
       WHERE id != $1
       ORDER BY name ASC`,
      [req.user.id]
    );

    const users = result.rows.map(u => ({
      id: u.id,
      userId: u.id,
      phone: u.phone,
      name: u.name,
      avatarUrl: u.avatar_url,
      status: u.status,
      isOnline: u.is_online,
      lastSeen: u.last_seen
    }));

    return ApiResponse.success(res, users);
  } catch (error) {
    logger.error('Get all users error:', error);
    return ApiResponse.serverError(res);
  }
};

// Get current user profile
const getMe = async (req, res) => {
  try {
    const result = await query(
      `SELECT id, phone, name, avatar_url, status, privacy_settings, created_at 
       FROM users WHERE id = $1`,
      [req.user.id]
    );

    return ApiResponse.success(res, {
      id: result.rows[0].id,
      phone: result.rows[0].phone,
      name: result.rows[0].name,
      avatarUrl: result.rows[0].avatar_url,
      status: result.rows[0].status,
      privacySettings: result.rows[0].privacy_settings,
      createdAt: result.rows[0].created_at
    });
  } catch (error) {
    logger.error('Get me error:', error);
    return ApiResponse.serverError(res);
  }
};

// Update profile
const updateProfile = async (req, res) => {
  try {
    const { name, status, avatarUrl } = req.body;

    const updates = [];
    const values = [];
    let paramCount = 1;

    if (name !== undefined) {
      updates.push(`name = $${paramCount++}`);
      values.push(name);
    }
    if (status !== undefined) {
      updates.push(`status = $${paramCount++}`);
      values.push(status);
    }
    if (avatarUrl !== undefined) {
      updates.push(`avatar_url = $${paramCount++}`);
      values.push(avatarUrl);
    }

    if (updates.length === 0) {
      return ApiResponse.error(res, 'No fields to update', 400);
    }

    values.push(req.user.id);

    const result = await query(
      `UPDATE users SET ${updates.join(', ')} WHERE id = $${paramCount} 
       RETURNING id, phone, name, avatar_url, status`,
      values
    );

    // Clear cache
    await cache.del(`user:${req.user.id}`);

    return ApiResponse.success(res, {
      id: result.rows[0].id,
      phone: result.rows[0].phone,
      name: result.rows[0].name,
      avatarUrl: result.rows[0].avatar_url,
      status: result.rows[0].status
    }, 'Profile updated');

  } catch (error) {
    logger.error('Update profile error:', error);
    return ApiResponse.serverError(res);
  }
};

// Update privacy settings
const updatePrivacy = async (req, res) => {
  try {
    const { lastSeen, avatar, status } = req.body;

    const privacySettings = {
      last_seen: lastSeen || 'everyone',
      avatar: avatar || 'everyone',
      status: status || 'everyone'
    };

    await query(
      'UPDATE users SET privacy_settings = $1 WHERE id = $2',
      [JSON.stringify(privacySettings), req.user.id]
    );

    await cache.del(`user:${req.user.id}`);

    return ApiResponse.success(res, { privacySettings }, 'Privacy settings updated');

  } catch (error) {
    logger.error('Update privacy error:', error);
    return ApiResponse.serverError(res);
  }
};

// Get user by ID
const getUserById = async (req, res) => {
  try {
    const { userId } = req.params;

    // Check if blocked
    const blockCheck = await query(
      'SELECT id FROM contacts WHERE user_id = $1 AND contact_user_id = $2 AND is_blocked = TRUE',
      [userId, req.user.id]
    );

    if (blockCheck.rows.length > 0) {
      return ApiResponse.forbidden(res, 'User not available');
    }

    const result = await query(
      `SELECT u.id, u.name, u.avatar_url, u.status, u.is_online, u.last_seen, u.privacy_settings,
              c.nickname, c.is_favorite, c.is_blocked
       FROM users u
       LEFT JOIN contacts c ON c.contact_user_id = u.id AND c.user_id = $2
       WHERE u.id = $1`,
      [userId, req.user.id]
    );

    if (result.rows.length === 0) {
      return ApiResponse.notFound(res, 'User not found');
    }

    const user = result.rows[0];
    const privacy = user.privacy_settings || {};

    // Apply privacy settings
    const response = {
      id: user.id,
      name: user.nickname || user.name,
      avatarUrl: privacy.avatar === 'nobody' ? null : user.avatar_url,
      status: privacy.status === 'nobody' ? null : user.status,
      isOnline: privacy.last_seen === 'nobody' ? null : user.is_online,
      lastSeen: privacy.last_seen === 'nobody' ? null : user.last_seen,
      isFavorite: user.is_favorite || false,
      isBlocked: user.is_blocked || false
    };

    return ApiResponse.success(res, response);

  } catch (error) {
    logger.error('Get user error:', error);
    return ApiResponse.serverError(res);
  }
};

// Get user devices
const getDevices = async (req, res) => {
  try {
    const result = await query(
      `SELECT id, device_type, device_name, app_version, is_active, last_active, created_at
       FROM user_devices 
       WHERE user_id = $1 
       ORDER BY last_active DESC`,
      [req.user.id]
    );

    return ApiResponse.success(res, result.rows.map(d => ({
      id: d.id,
      deviceType: d.device_type,
      deviceName: d.device_name,
      appVersion: d.app_version,
      isActive: d.is_active,
      lastActive: d.last_active,
      isCurrent: d.id === req.deviceId,
      createdAt: d.created_at
    })));

  } catch (error) {
    logger.error('Get devices error:', error);
    return ApiResponse.serverError(res);
  }
};

// Revoke device
const revokeDevice = async (req, res) => {
  try {
    const { deviceId } = req.params;

    if (deviceId === req.deviceId) {
      return ApiResponse.error(res, 'Cannot revoke current device', 400);
    }

    await query(
      'UPDATE user_devices SET is_active = FALSE WHERE id = $1 AND user_id = $2',
      [deviceId, req.user.id]
    );

    await query(
      'UPDATE refresh_tokens SET revoked_at = NOW() WHERE device_id = $1',
      [deviceId]
    );

    return ApiResponse.success(res, null, 'Device revoked');

  } catch (error) {
    logger.error('Revoke device error:', error);
    return ApiResponse.serverError(res);
  }
};

// Update push token
const updatePushToken = async (req, res) => {
  try {
    const { pushToken } = req.body;

    await query(
      'UPDATE user_devices SET push_token = $1 WHERE id = $2',
      [pushToken, req.deviceId]
    );

    return ApiResponse.success(res, null, 'Push token updated');

  } catch (error) {
    logger.error('Update push token error:', error);
    return ApiResponse.serverError(res);
  }
};

// Delete account
const deleteAccount = async (req, res) => {
  try {
    // Soft delete - just anonymize data
    await query(
      `UPDATE users SET 
         phone = 'deleted_' || id,
         phone_hash = 'deleted_' || id,
         name = 'Deleted User',
         avatar_url = NULL,
         status = NULL
       WHERE id = $1`,
      [req.user.id]
    );

    // Revoke all tokens
    await query(
      'UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = $1',
      [req.user.id]
    );

    await cache.del(`user:${req.user.id}`);

    return ApiResponse.success(res, null, 'Account deleted');

  } catch (error) {
    logger.error('Delete account error:', error);
    return ApiResponse.serverError(res);
  }
};

module.exports = {
  getAllUsers,
  getMe,
  updateProfile,
  updatePrivacy,
  getUserById,
  getDevices,
  revokeDevice,
  updatePushToken,
  deleteAccount
};
