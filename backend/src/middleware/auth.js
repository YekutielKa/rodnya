const { verifyAccessToken } = require('../utils/jwt');
const { query } = require('../config/database');
const { cache } = require('../config/redis');
const ApiResponse = require('../utils/response');
const logger = require('../utils/logger');

const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return ApiResponse.unauthorized(res, 'No token provided');
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyAccessToken(token);

    if (!decoded) {
      return ApiResponse.unauthorized(res, 'Invalid or expired token');
    }

    // Check cache first
    let user = await cache.get(`user:${decoded.userId}`);
    
    if (!user) {
      const result = await query(
        'SELECT id, phone, name, avatar_url, status, is_online, privacy_settings FROM users WHERE id = $1',
        [decoded.userId]
      );

      if (result.rows.length === 0) {
        return ApiResponse.unauthorized(res, 'User not found');
      }

      user = result.rows[0];
      await cache.set(`user:${decoded.userId}`, user, 300); // Cache for 5 min
    }

    req.user = user;
    req.deviceId = decoded.deviceId;
    next();
  } catch (error) {
    logger.error('Auth middleware error:', error);
    return ApiResponse.serverError(res);
  }
};

const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyAccessToken(token);

    if (decoded) {
      const result = await query(
        'SELECT id, phone, name, avatar_url, status, is_online FROM users WHERE id = $1',
        [decoded.userId]
      );

      if (result.rows.length > 0) {
        req.user = result.rows[0];
        req.deviceId = decoded.deviceId;
      }
    }

    next();
  } catch (error) {
    next();
  }
};

const requireRole = (roles) => {
  return async (req, res, next) => {
    if (!req.user) {
      return ApiResponse.unauthorized(res);
    }

    // For group chats, check user role
    const chatId = req.params.chatId || req.body.chatId;
    if (chatId) {
      const result = await query(
        'SELECT role FROM chat_members WHERE chat_id = $1 AND user_id = $2',
        [chatId, req.user.id]
      );

      if (result.rows.length === 0) {
        return ApiResponse.forbidden(res, 'Not a member of this chat');
      }

      if (!roles.includes(result.rows[0].role)) {
        return ApiResponse.forbidden(res, 'Insufficient permissions');
      }
    }

    next();
  };
};

module.exports = { authenticate, optionalAuth, requireRole };
