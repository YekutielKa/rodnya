const express = require('express');
const router = express.Router();

const authController = require('../controllers/authController');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { authLimiter, otpLimiter } = require('../middleware/rateLimiter');
const {
  sendOtpValidator,
  verifyOtpValidator,
  registerValidator,
  refreshTokenValidator
} = require('../validators/auth');

// Public routes
router.post('/otp/send', otpLimiter, sendOtpValidator, validate, authController.sendOtp);
router.post('/otp/verify', authLimiter, verifyOtpValidator, validate, authController.verifyOtp);
router.post('/register', authLimiter, registerValidator, validate, authController.register);
router.post('/login', authLimiter, registerValidator, validate, authController.login);
router.post('/refresh', refreshTokenValidator, validate, authController.refreshAccessToken);

// Protected routes
router.post('/logout', authenticate, authController.logout);
router.post('/logout-all', authenticate, authController.logoutAll);
router.post('/invite', authenticate, authController.createInvite);

module.exports = router;
