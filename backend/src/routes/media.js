const express = require('express');
const router = express.Router();
const { body, param, query: queryValidator } = require('express-validator');

const mediaController = require('../controllers/mediaController');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { uploadLimiter } = require('../middleware/rateLimiter');

router.use(authenticate);

// Get upload URL
router.post('/upload-url', [
  body('type').isIn(['image', 'video', 'voice', 'file', 'avatar']),
  body('mimeType').trim().notEmpty(),
  body('fileName').trim().notEmpty()
], validate, mediaController.getUploadUrl);

// Upload file
router.put('/upload/:fileId', 
  uploadLimiter,
  express.raw({ type: '*/*', limit: '50mb' }),
  [param('fileId').isUUID()],
  validate,
  mediaController.uploadFile
);

// Get user's files
router.get('/my-files', [
  queryValidator('type').optional().isIn(['image', 'video', 'voice', 'file', 'avatar']),
  queryValidator('limit').optional().isInt({ min: 1, max: 100 }),
  queryValidator('offset').optional().isInt({ min: 0 })
], validate, mediaController.getUserFiles);

// Get file
router.get('/files/*', mediaController.getFile);

// Delete file
router.delete('/:fileId', [
  param('fileId').isUUID()
], validate, mediaController.deleteFile);

module.exports = router;
