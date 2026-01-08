const express = require('express');
const router = express.Router();
const { body, param, query: queryValidator } = require('express-validator');

const chatController = require('../controllers/chatController');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

router.use(authenticate);

// List chats
router.get('/', [
  queryValidator('page').optional().isInt({ min: 1 }),
  queryValidator('limit').optional().isInt({ min: 1, max: 100 }),
  queryValidator('archived').optional().isBoolean()
], validate, chatController.getChats);

// Direct chat
router.post('/direct', [
  body('userId').isUUID()
], validate, chatController.getOrCreateDirectChat);

// Group chat
router.post('/group', [
  body('name').trim().isLength({ min: 1, max: 100 }),
  body('memberIds').isArray({ min: 1 }),
  body('memberIds.*').isUUID(),
  body('avatarUrl').optional().isURL()
], validate, chatController.createGroupChat);

// Chat by ID
router.get('/:chatId', [
  param('chatId').isUUID()
], validate, chatController.getChatById);

router.patch('/:chatId', [
  param('chatId').isUUID(),
  body('name').optional().trim().isLength({ min: 1, max: 100 }),
  body('description').optional().trim().isLength({ max: 500 }),
  body('avatarUrl').optional().isURL()
], validate, chatController.updateChat);

// Chat settings
router.patch('/:chatId/settings', [
  param('chatId').isUUID(),
  body('isPinned').optional().isBoolean(),
  body('isMuted').optional().isBoolean(),
  body('isArchived').optional().isBoolean(),
  body('mutedUntil').optional().isISO8601()
], validate, chatController.updateChatSettings);

// Read status
router.post('/:chatId/read', [
  param('chatId').isUUID(),
  body('messageId').optional().isUUID()
], validate, chatController.markAsRead);

// Members
router.post('/:chatId/members', [
  param('chatId').isUUID(),
  body('userId').isUUID()
], validate, chatController.addMember);

router.delete('/:chatId/members/:userId', [
  param('chatId').isUUID(),
  param('userId').isUUID()
], validate, chatController.removeMember);

module.exports = router;
