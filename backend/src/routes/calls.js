const express = require('express');
const router = express.Router();
const { body, param, query: queryValidator } = require('express-validator');

const callController = require('../controllers/callController');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

router.use(authenticate);

// Call history
router.get('/history', [
  queryValidator('limit').optional().isInt({ min: 1, max: 100 }),
  queryValidator('offset').optional().isInt({ min: 0 })
], validate, callController.getCallHistory);

// TURN credentials
router.get('/turn-credentials', callController.getTurnCredentials);

// Initiate call
router.post('/', [
  body('chatId').isUUID(),
  body('type').isIn(['audio', 'video'])
], validate, callController.initiateCall);

// Accept call
router.post('/:callId/accept', [
  param('callId').isUUID()
], validate, callController.acceptCall);

// Reject call
router.post('/:callId/reject', [
  param('callId').isUUID(),
  body('reason').optional().trim()
], validate, callController.rejectCall);

// End call
router.post('/:callId/end', [
  param('callId').isUUID()
], validate, callController.endCall);

// WebRTC signaling
router.post('/:callId/signal', [
  param('callId').isUUID(),
  body('targetUserId').isUUID(),
  body('signal').isObject()
], validate, callController.sendSignal);

module.exports = router;
