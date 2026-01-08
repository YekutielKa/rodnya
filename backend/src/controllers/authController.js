const { query, transaction } = require('../config/database');
const { cache } = require('../config/redis');
const {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
  hashToken,
  generateOTP,
  hashPhone,
  generateInviteCode
} = require('../utils/jwt');
const ApiResponse = require('../utils/response');
const logger = require('../utils/logger');

// Send OTP
const sendOtp = async (req, res) => {
  try {
    const { phone } = req.body;

    // Check if user exists (for determining flow)
    const existingUser = await query(
      'SELECT id FROM users WHERE phone = $1',
      [phone]
    );

    // Generate OTP
    const otp = generateOTP();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

    // Invalidate previous OTPs
    await query(
      'UPDATE otp_codes SET verified_at = NOW() WHERE phone = $1 AND verified_at IS NULL',
      [phone]
    );

    // Save new OTP
    await query(
      'INSERT INTO otp_codes (phone, code, expires_at) VALUES ($1, $2, $3)',
      [phone, otp, expiresAt]
    );

    // In production, send via SMS/Telegram
    // For now, log it (remove in production!)
    logger.info(`OTP for ${phone}: ${otp}`);

    // TODO: Integrate SMS provider (Twilio, SMS.ru, etc.)
    // await smsService.send(phone, `Ваш код для Rodnya: ${otp}`);

    return ApiResponse.success(res, {
      isNewUser: existingUser.rows.length === 0,
      expiresIn: 300 // seconds
    }, 'OTP sent successfully');

  } catch (error) {
    logger.error('Send OTP error:', error);
    return ApiResponse.serverError(res);
  }
};

// Verify OTP
const verifyOtp = async (req, res) => {
  try {
    const { phone, code } = req.body;

    // Get latest OTP
    const otpResult = await query(
      `SELECT id, code, attempts, expires_at 
       FROM otp_codes 
       WHERE phone = $1 AND verified_at IS NULL 
       ORDER BY created_at DESC 
       LIMIT 1`,
      [phone]
    );

    if (otpResult.rows.length === 0) {
      return ApiResponse.error(res, 'No pending OTP found', 400);
    }

    const otpRecord = otpResult.rows[0];

    // Check expiry
    if (new Date(otpRecord.expires_at) < new Date()) {
      return ApiResponse.error(res, 'OTP expired', 400);
    }

    // Check attempts
    if (otpRecord.attempts >= 5) {
      return ApiResponse.error(res, 'Too many attempts', 429);
    }

    // Verify code
    if (otpRecord.code !== code) {
      await query(
        'UPDATE otp_codes SET attempts = attempts + 1 WHERE id = $1',
        [otpRecord.id]
      );
      return ApiResponse.error(res, 'Invalid OTP', 400);
    }

    // Mark as verified
    await query(
      'UPDATE otp_codes SET verified_at = NOW() WHERE id = $1',
      [otpRecord.id]
    );

    // Check if user exists
    const userResult = await query(
      'SELECT id, phone, name, avatar_url FROM users WHERE phone = $1',
      [phone]
    );

    if (userResult.rows.length > 0) {
      // Existing user - generate tokens
      const user = userResult.rows[0];
      
      return ApiResponse.success(res, {
        isNewUser: false,
        user: {
          id: user.id,
          phone: user.phone,
          name: user.name,
          avatarUrl: user.avatar_url
        },
        verificationToken: hashToken(phone + Date.now()) // Temp token for registration
      });
    }

    // New user - return verification token
    return ApiResponse.success(res, {
      isNewUser: true,
      verificationToken: hashToken(phone + Date.now())
    });

  } catch (error) {
    logger.error('Verify OTP error:', error);
    return ApiResponse.serverError(res);
  }
};

// Register new user
const register = async (req, res) => {
  try {
    const { phone, name, inviteCode, deviceId, deviceType, deviceName } = req.body;

    // Check if invite system is enabled and validate invite
    if (process.env.REQUIRE_INVITE === 'true') {
      if (!inviteCode) {
        return ApiResponse.error(res, 'Invite code required', 400);
      }

      const inviteResult = await query(
        `SELECT id, max_uses, use_count, expires_at 
         FROM invites 
         WHERE code = $1 AND used_by IS NULL`,
        [inviteCode]
      );

      if (inviteResult.rows.length === 0) {
        return ApiResponse.error(res, 'Invalid invite code', 400);
      }

      const invite = inviteResult.rows[0];

      if (invite.expires_at && new Date(invite.expires_at) < new Date()) {
        return ApiResponse.error(res, 'Invite code expired', 400);
      }

      if (invite.use_count >= invite.max_uses) {
        return ApiResponse.error(res, 'Invite code already used', 400);
      }
    }

    // Check if phone already registered
    const existingUser = await query(
      'SELECT id FROM users WHERE phone = $1',
      [phone]
    );

    if (existingUser.rows.length > 0) {
      return ApiResponse.error(res, 'Phone already registered', 409);
    }

    // Create user with transaction
    const result = await transaction(async (client) => {
      // Create user
      const userResult = await client.query(
        `INSERT INTO users (phone, phone_hash, name) 
         VALUES ($1, $2, $3) 
         RETURNING id, phone, name, avatar_url, status, created_at`,
        [phone, hashPhone(phone), name]
      );

      const user = userResult.rows[0];

      // Create device
      const deviceResult = await client.query(
        `INSERT INTO user_devices (user_id, device_id, device_type, device_name) 
         VALUES ($1, $2, $3, $4) 
         RETURNING id`,
        [user.id, deviceId, deviceType, deviceName || null]
      );

      // Generate tokens
      const accessToken = generateAccessToken({ userId: user.id, deviceId: deviceResult.rows[0].id });
      const refreshToken = generateRefreshToken({ userId: user.id, deviceId: deviceResult.rows[0].id });

      // Save refresh token
      await client.query(
        `INSERT INTO refresh_tokens (user_id, device_id, token_hash, expires_at) 
         VALUES ($1, $2, $3, NOW() + INTERVAL '30 days')`,
        [user.id, deviceResult.rows[0].id, hashToken(refreshToken)]
      );

      // Mark invite as used
      if (inviteCode) {
        await client.query(
          `UPDATE invites 
           SET used_by = $1, used_at = NOW(), use_count = use_count + 1 
           WHERE code = $2`,
          [user.id, inviteCode]
        );
      }

      return {
        user,
        accessToken,
        refreshToken,
        deviceId: deviceResult.rows[0].id
      };
    });

    return ApiResponse.created(res, {
      user: {
        id: result.user.id,
        phone: result.user.phone,
        name: result.user.name,
        avatarUrl: result.user.avatar_url,
        status: result.user.status
      },
      accessToken: result.accessToken,
      refreshToken: result.refreshToken
    }, 'Registration successful');

  } catch (error) {
    logger.error('Register error:', error);
    return ApiResponse.serverError(res);
  }
};

// Login existing user
const login = async (req, res) => {
  try {
    const { phone, deviceId, deviceType, deviceName } = req.body;

    // Get user
    const userResult = await query(
      'SELECT id, phone, name, avatar_url, status FROM users WHERE phone = $1',
      [phone]
    );

    if (userResult.rows.length === 0) {
      return ApiResponse.error(res, 'User not found', 404);
    }

    const user = userResult.rows[0];

    // Upsert device
    const deviceResult = await query(
      `INSERT INTO user_devices (user_id, device_id, device_type, device_name, last_active) 
       VALUES ($1, $2, $3, $4, NOW()) 
       ON CONFLICT (user_id, device_id) 
       DO UPDATE SET device_type = $3, device_name = $4, last_active = NOW(), is_active = TRUE
       RETURNING id`,
      [user.id, deviceId, deviceType, deviceName || null]
    );

    // Generate tokens
    const accessToken = generateAccessToken({ userId: user.id, deviceId: deviceResult.rows[0].id });
    const refreshToken = generateRefreshToken({ userId: user.id, deviceId: deviceResult.rows[0].id });

    // Save refresh token
    await query(
      `INSERT INTO refresh_tokens (user_id, device_id, token_hash, expires_at) 
       VALUES ($1, $2, $3, NOW() + INTERVAL '30 days')`,
      [user.id, deviceResult.rows[0].id, hashToken(refreshToken)]
    );

    // Update online status
    await query('UPDATE users SET is_online = TRUE, last_seen = NOW() WHERE id = $1', [user.id]);

    return ApiResponse.success(res, {
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        avatarUrl: user.avatar_url,
        status: user.status
      },
      accessToken,
      refreshToken
    });

  } catch (error) {
    logger.error('Login error:', error);
    return ApiResponse.serverError(res);
  }
};

// Refresh token
const refreshAccessToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    const decoded = verifyRefreshToken(refreshToken);
    if (!decoded) {
      return ApiResponse.unauthorized(res, 'Invalid refresh token');
    }

    // Check if token exists and not revoked
    const tokenResult = await query(
      `SELECT rt.id, rt.user_id, rt.device_id, u.phone, u.name, u.avatar_url, u.status
       FROM refresh_tokens rt
       JOIN users u ON u.id = rt.user_id
       WHERE rt.token_hash = $1 AND rt.revoked_at IS NULL AND rt.expires_at > NOW()`,
      [hashToken(refreshToken)]
    );

    if (tokenResult.rows.length === 0) {
      return ApiResponse.unauthorized(res, 'Token expired or revoked');
    }

    const { user_id, device_id, phone, name, avatar_url, status } = tokenResult.rows[0];

    // Generate new tokens
    const newAccessToken = generateAccessToken({ userId: user_id, deviceId: device_id });
    const newRefreshToken = generateRefreshToken({ userId: user_id, deviceId: device_id });

    // Revoke old and save new refresh token
    await query('UPDATE refresh_tokens SET revoked_at = NOW() WHERE token_hash = $1', [hashToken(refreshToken)]);
    await query(
      `INSERT INTO refresh_tokens (user_id, device_id, token_hash, expires_at) 
       VALUES ($1, $2, $3, NOW() + INTERVAL '30 days')`,
      [user_id, device_id, hashToken(newRefreshToken)]
    );

    return ApiResponse.success(res, {
      user: { id: user_id, phone, name, avatarUrl: avatar_url, status },
      accessToken: newAccessToken,
      refreshToken: newRefreshToken
    });

  } catch (error) {
    logger.error('Refresh token error:', error);
    return ApiResponse.serverError(res);
  }
};

// Logout
const logout = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (refreshToken) {
      await query(
        'UPDATE refresh_tokens SET revoked_at = NOW() WHERE token_hash = $1',
        [hashToken(refreshToken)]
      );
    }

    // Update device
    if (req.deviceId) {
      await query(
        'UPDATE user_devices SET is_active = FALSE WHERE id = $1',
        [req.deviceId]
      );
    }

    // Update user online status
    await query(
      'UPDATE users SET is_online = FALSE, last_seen = NOW() WHERE id = $1',
      [req.user.id]
    );

    // Clear cache
    await cache.del(`user:${req.user.id}`);

    return ApiResponse.success(res, null, 'Logged out successfully');

  } catch (error) {
    logger.error('Logout error:', error);
    return ApiResponse.serverError(res);
  }
};

// Logout from all devices
const logoutAll = async (req, res) => {
  try {
    await query(
      'UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL',
      [req.user.id]
    );

    await query(
      'UPDATE user_devices SET is_active = FALSE WHERE user_id = $1',
      [req.user.id]
    );

    await query(
      'UPDATE users SET is_online = FALSE, last_seen = NOW() WHERE id = $1',
      [req.user.id]
    );

    await cache.del(`user:${req.user.id}`);

    return ApiResponse.success(res, null, 'Logged out from all devices');

  } catch (error) {
    logger.error('Logout all error:', error);
    return ApiResponse.serverError(res);
  }
};

// Generate invite code
const createInvite = async (req, res) => {
  try {
    const { maxUses = 1, expiresInDays = 7 } = req.body;

    const code = generateInviteCode();
    const expiresAt = expiresInDays ? new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000) : null;

    await query(
      'INSERT INTO invites (code, created_by, max_uses, expires_at) VALUES ($1, $2, $3, $4)',
      [code, req.user.id, maxUses, expiresAt]
    );

    return ApiResponse.created(res, {
      code,
      maxUses,
      expiresAt
    }, 'Invite created');

  } catch (error) {
    logger.error('Create invite error:', error);
    return ApiResponse.serverError(res);
  }
};

module.exports = {
  sendOtp,
  verifyOtp,
  register,
  login,
  refreshAccessToken,
  logout,
  logoutAll,
  createInvite
};
