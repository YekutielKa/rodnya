const express = require('express');
const router = express.Router();
const multer = require('multer');
const { body } = require('express-validator');
const mediaController = require('../controllers/mediaController');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 100 * 1024 * 1024 }
});

router.use(authenticate);

router.post('/upload',
  upload.single('file'),
  [body('type').optional().isIn(['image', 'video', 'voice', 'file'])],
  validate,
  mediaController.uploadMedia
);

router.delete('/:key(*)', mediaController.deleteMedia);

module.exports = router;
