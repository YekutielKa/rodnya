const { body, param } = require('express-validator');

const phoneRegex = /^\+?[1-9]\d{6,14}$/;

const sendOtpValidator = [
  body('phone')
    .trim()
    .notEmpty().withMessage('Phone number is required')
    .matches(phoneRegex).withMessage('Invalid phone number format')
];

const verifyOtpValidator = [
  body('phone')
    .trim()
    .notEmpty().withMessage('Phone number is required')
    .matches(phoneRegex).withMessage('Invalid phone number format'),
  body('code')
    .trim()
    .notEmpty().withMessage('OTP code is required')
    .isLength({ min: 6, max: 6 }).withMessage('OTP must be 6 digits')
    .isNumeric().withMessage('OTP must contain only numbers')
];

const registerValidator = [
  body('phone')
    .trim()
    .notEmpty().withMessage('Phone number is required')
    .matches(phoneRegex).withMessage('Invalid phone number format'),
  body('name').optional()
    .trim()
    
    .isLength({ min: 2, max: 100 }).withMessage('Name must be 2-100 characters'),
  body('inviteCode')
    .optional()
    .trim()
    .isLength({ min: 6, max: 20 }).withMessage('Invalid invite code'),
  body('deviceId')
    .trim()
    .notEmpty().withMessage('Device ID is required'),
  body('deviceType')
    .trim()
    .notEmpty().withMessage('Device type is required')
    .isIn(['ios', 'android', 'web']).withMessage('Invalid device type'),
  body('deviceName')
    .optional()
    .trim()
    .isLength({ max: 100 }).withMessage('Device name too long')
];

const refreshTokenValidator = [
  body('refreshToken')
    .trim()
    .notEmpty().withMessage('Refresh token is required')
];

const deviceValidator = [
  body('deviceId')
    .trim()
    .notEmpty().withMessage('Device ID is required'),
  body('deviceType')
    .trim()
    .notEmpty().withMessage('Device type is required')
    .isIn(['ios', 'android', 'web']).withMessage('Invalid device type'),
  body('pushToken')
    .optional()
    .trim()
];


const loginValidator = [
  body('phone')
    .trim()
    .notEmpty().withMessage('Phone number is required')
    .matches(phoneRegex).withMessage('Invalid phone number format'),
  body('deviceId')
    .trim()
    .notEmpty().withMessage('Device ID is required'),
  body('deviceType')
    .trim()
    .notEmpty().withMessage('Device type is required')
    .isIn(['ios', 'android', 'web', 'mobile']).withMessage('Invalid device type'),
  body('deviceName')
    .optional()
    .trim()
    .isLength({ max: 100 }).withMessage('Device name too long')
];

module.exports = {
  loginValidator,
  sendOtpValidator,
  verifyOtpValidator,
  registerValidator,
  refreshTokenValidator,
  deviceValidator
};
