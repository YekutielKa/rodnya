const { query } = require('../config/database');
const logger = require('../utils/logger');
const ApiResponse = require('../utils/response');
const mediaService = require('../services/mediaService');

const uploadMedia = async (req, res) => {
  try {
    if (!req.file) {
      return ApiResponse.error(res, 'No file provided', 400);
    }
    const { type = 'file' } = req.body;
    const result = await mediaService.uploadMedia(req.file, req.user.id, type);
    await query(
      `INSERT INTO media_files (uploader_id, type, original_name, mime_type, size_bytes, storage_key)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
      [req.user.id, type, result.fileName, result.mimeType, result.fileSize, result.key]
    );
    return ApiResponse.success(res, result);
  } catch (error) {
    logger.error('Upload media error:', error);
    if (error.message.includes('Invalid') || error.message.includes('too large')) {
      return ApiResponse.error(res, error.message, 400);
    }
    return ApiResponse.serverError(res);
  }
};

const deleteMedia = async (req, res) => {
  try {
    const { key } = req.params;
    const mediaCheck = await query(
      'SELECT id FROM media_files WHERE storage_key = $1 AND uploader_id = $2',
      [key, req.user.id]
    );
    if (mediaCheck.rows.length === 0) {
      return ApiResponse.forbidden(res, 'Cannot delete this file');
    }
    await mediaService.deleteMedia(key);
    await query('DELETE FROM media_files WHERE storage_key = $1', [key]);
    return ApiResponse.success(res, { deleted: true });
  } catch (error) {
    logger.error('Delete media error:', error);
    return ApiResponse.serverError(res);
  }
};

module.exports = { uploadMedia, deleteMedia };
