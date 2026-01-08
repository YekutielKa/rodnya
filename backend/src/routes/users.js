const express = require('express');
const router = express.Router();
const { body, param } = require('express-validator');

const userController = require('../controllers/userController');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

router.use(authenticate);

router.get('/me', userController.getMe);

router.patch('/me', [
  body('name').optional().trim().isLength({ min: 2, max: 100 }),
  body('status').optional().trim().isLength({ max: 200 }),
  body('avatarUrl').optional({ values: 'falsy' }).trim().isURL()
], validate, userController.updateProfile);

router.patch('/me/privacy', [
  body('lastSeen').optional().isIn(['everyone', 'contacts', 'nobody']),
  body('avatar').optional().isIn(['everyone', 'contacts', 'nobody']),
  body('status').optional().isIn(['everyone', 'contacts', 'nobody'])
], validate, userController.updatePrivacy);

router.delete('/me', userController.deleteAccount);

router.get('/devices', userController.getDevices);
router.delete('/devices/:deviceId', [
  param('deviceId').isUUID()
], validate, userController.revokeDevice);

router.patch('/push-token', [
  body('pushToken').trim().notEmpty()
], validate, userController.updatePushToken);

router.get('/:userId', [
  param('userId').isUUID()
], validate, userController.getUserById);

module.exports = router;
