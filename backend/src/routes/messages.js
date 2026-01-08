const express = require('express');
const router = express.Router();
const { body, param, query: queryValidator } = require('express-validator');

const messageController = require('../controllers/messageController');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { messageLimiter } = require('../middleware/rateLimiter');

router.use(authenticate);

// Search messages in chat
router.get('/chat/:chatId/search', [
  param('chatId').isUUID(),
  queryValidator('q').trim().isLength({ min: 2 }),
  queryValidator('limit').optional().isInt({ min: 1, max: 50 })
], validate, messageController.searchMessages);

// Get messages for chat
router.get('/chat/:chatId', [
  param('chatId').isUUID(),
  queryValidator('before').optional().isISO8601(),
  queryValidator('after').optional().isISO8601(),
  queryValidator('limit').optional().isInt({ min: 1, max: 100 })
], validate, messageController.getMessages);

// Send message
router.post('/chat/:chatId', messageLimiter, [
  param('chatId').isUUID(),
  body('type').optional().isIn(['text', 'image', 'video', 'voice', 'file', 'location', 'contact', 'sticker']),
  body('content').trim().notEmpty(),
  body('metadata').optional().isObject(),
  body('replyToId').optional().isUUID()
], validate, messageController.sendMessage);

// Edit message
router.patch('/:messageId/chat/:chatId', [
  param('chatId').isUUID(),
  param('messageId').isUUID(),
  body('content').trim().notEmpty()
], validate, messageController.editMessage);

// Delete message
router.delete('/:messageId/chat/:chatId', [
  param('chatId').isUUID(),
  param('messageId').isUUID(),
  body('forEveryone').optional().isBoolean()
], validate, messageController.deleteMessage);

// Update status
router.patch('/:messageId/chat/:chatId/status', [
  param('chatId').isUUID(),
  param('messageId').isUUID(),
  body('status').isIn(['delivered', 'read'])
], validate, messageController.updateMessageStatus);

module.exports = router;
