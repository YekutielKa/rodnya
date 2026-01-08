const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs').promises;
const logger = require('../utils/logger');

const UPLOAD_DIR = process.env.UPLOAD_DIR || '/tmp/rodnya-uploads';

const ALLOWED_TYPES = {
  image: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
  video: ['video/mp4', 'video/quicktime', 'video/webm'],
  voice: ['audio/mpeg', 'audio/mp4', 'audio/ogg', 'audio/webm', 'audio/wav', 'audio/m4a'],
  file: ['application/pdf', 'application/msword', 'text/plain', 'application/zip']
};

const MAX_SIZES = {
  image: 10 * 1024 * 1024,
  video: 100 * 1024 * 1024,
  voice: 10 * 1024 * 1024,
  file: 50 * 1024 * 1024,
};

const validateFile = (file, type) => {
  const allowedMimes = ALLOWED_TYPES[type] || ALLOWED_TYPES.file;
  const maxSize = MAX_SIZES[type] || MAX_SIZES.file;
  if (!allowedMimes.includes(file.mimetype)) {
    throw new Error('Invalid file type');
  }
  if (file.size > maxSize) {
    throw new Error('File too large');
  }
  return true;
};

const generateKey = (userId, type, originalName) => {
  const ext = path.extname(originalName).toLowerCase();
  const timestamp = Date.now();
  const uniqueId = uuidv4().substring(0, 8);
  return `${type}/${userId}/${timestamp}-${uniqueId}${ext}`;
};

const uploadMedia = async (file, userId, type = 'file') => {
  validateFile(file, type);
  const key = generateKey(userId, type, file.originalname || 'file');
  const filePath = path.join(UPLOAD_DIR, key);
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, file.buffer);
  const baseUrl = process.env.MEDIA_BASE_URL || process.env.BASE_URL + '/uploads';
  return {
    url: baseUrl + '/' + key,
    thumbnailUrl: null,
    key,
    fileName: file.originalname,
    fileSize: file.size,
    mimeType: file.mimetype,
  };
};

const deleteMedia = async (key) => {
  try {
    const filePath = path.join(UPLOAD_DIR, key);
    await fs.unlink(filePath);
    return true;
  } catch (error) {
    logger.error('Delete media error:', error);
    return false;
  }
};

module.exports = { uploadMedia, deleteMedia, validateFile };
