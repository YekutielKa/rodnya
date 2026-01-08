const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const JWT_SECRET = process.env.JWT_SECRET;
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET;
const ACCESS_TOKEN_EXPIRES = '15m';
const REFRESH_TOKEN_EXPIRES = '30d';

const generateAccessToken = (payload) => {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: ACCESS_TOKEN_EXPIRES });
};

const generateRefreshToken = (payload) => {
  return jwt.sign(payload, JWT_REFRESH_SECRET, { expiresIn: REFRESH_TOKEN_EXPIRES });
};

const verifyAccessToken = (token) => {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    return null;
  }
};

const verifyRefreshToken = (token) => {
  try {
    return jwt.verify(token, JWT_REFRESH_SECRET);
  } catch (error) {
    return null;
  }
};

const hashToken = (token) => {
  return crypto.createHash('sha256').update(token).digest('hex');
};

const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

const hashPhone = (phone) => {
  return crypto.createHash('sha256').update(phone + process.env.JWT_SECRET).digest('hex');
};

const generateInviteCode = () => {
  return crypto.randomBytes(6).toString('hex').toUpperCase();
};

const generateTurnCredentials = (userId) => {
  const secret = process.env.TURN_SECRET;
  const ttl = 86400; // 24 hours
  const timestamp = Math.floor(Date.now() / 1000) + ttl;
  const username = `${timestamp}:${userId}`;
  const hmac = crypto.createHmac('sha1', secret);
  hmac.update(username);
  const credential = hmac.digest('base64');
  
  return {
    username,
    credential,
    ttl,
    urls: [
      `turn:${process.env.TURN_SERVER || 'turn.rodnya.family'}:3478`,
      `turn:${process.env.TURN_SERVER || 'turn.rodnya.family'}:3478?transport=tcp`,
      `turns:${process.env.TURN_SERVER || 'turn.rodnya.family'}:5349`
    ]
  };
};

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  hashToken,
  generateOTP,
  hashPhone,
  generateInviteCode,
  generateTurnCredentials,
  ACCESS_TOKEN_EXPIRES,
  REFRESH_TOKEN_EXPIRES
};
