const { query } = require('../config/database');
const ApiResponse = require('../utils/response');
const logger = require('../utils/logger');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs').promises;

// For local storage (replace with S3/R2 in production)
const UPLOAD_DIR = process.env.UPLOAD_DIR || '/tmp/rodnya-uploads';

// Ensure upload directory exists
const ensureUploadDir = async () => {
  try {
    await fs.mkdir(UPLOAD_DIR, { recursive: true });
  } catch (error) {
    logger.error('Failed to create upload directory:', error);
  }
};
ensureUploadDir();

// Get upload URL (presigned or local endpoint)
const getUploadUrl = async (req, res) => {
  try {
    const { type, mimeType, fileName } = req.body;

    const fileId = uuidv4();
    const ext = path.extname(fileName) || '';
    const storageKey = `${type}/${req.user.id}/${fileId}${ext}`;

    // For local storage, return upload endpoint
    // In production, generate S3 presigned URL
    const uploadUrl = `/api/v1/media/upload/${fileId}`;

    // Pre-create media record
    await query(
      `INSERT INTO media_files (id, uploader_id, type, original_name, mime_type, storage_key)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [fileId, req.user.id, type, fileName, mimeType, storageKey]
    );

    return ApiResponse.success(res, {
      uploadUrl,
      fileId,
      storageKey
    });

  } catch (error) {
    logger.error('Get upload URL error:', error);
    return ApiResponse.serverError(res);
  }
};

// Upload file (local storage fallback)
const uploadFile = async (req, res) => {
  try {
    const { fileId } = req.params;

    // Verify file record exists and belongs to user
    const fileRecord = await query(
      'SELECT * FROM media_files WHERE id = $1 AND uploader_id = $2',
      [fileId, req.user.id]
    );

    if (fileRecord.rows.length === 0) {
      return ApiResponse.notFound(res, 'Upload not initialized');
    }

    const file = fileRecord.rows[0];

    // Handle file upload (using raw body or multipart)
    if (!req.body || !Buffer.isBuffer(req.body)) {
      return ApiResponse.error(res, 'No file data', 400);
    }

    const filePath = path.join(UPLOAD_DIR, file.storage_key);
    const dirPath = path.dirname(filePath);
    
    await fs.mkdir(dirPath, { recursive: true });
    await fs.writeFile(filePath, req.body);

    // Update file record with size
    await query(
      'UPDATE media_files SET size_bytes = $1 WHERE id = $2',
      [req.body.length, fileId]
    );

    return ApiResponse.success(res, {
      fileId,
      url: `/api/v1/media/files/${file.storage_key}`
    });

  } catch (error) {
    logger.error('Upload file error:', error);
    return ApiResponse.serverError(res);
  }
};

// Get file
const getFile = async (req, res) => {
  try {
    const storageKey = req.params[0]; // Wildcard param

    const fileRecord = await query(
      'SELECT * FROM media_files WHERE storage_key = $1',
      [storageKey]
    );

    if (fileRecord.rows.length === 0) {
      return ApiResponse.notFound(res, 'File not found');
    }

    const file = fileRecord.rows[0];

    // Check access (for now, allow all authenticated users)
    // In production, add proper access control

    const filePath = path.join(UPLOAD_DIR, storageKey);

    try {
      await fs.access(filePath);
    } catch {
      return ApiResponse.notFound(res, 'File not found on disk');
    }

    res.setHeader('Content-Type', file.mime_type || 'application/octet-stream');
    res.setHeader('Content-Disposition', `inline; filename="${file.original_name}"`);
    
    const fileBuffer = await fs.readFile(filePath);
    return res.send(fileBuffer);

  } catch (error) {
    logger.error('Get file error:', error);
    return ApiResponse.serverError(res);
  }
};

// Delete file
const deleteFile = async (req, res) => {
  try {
    const { fileId } = req.params;

    const fileRecord = await query(
      'SELECT * FROM media_files WHERE id = $1 AND uploader_id = $2',
      [fileId, req.user.id]
    );

    if (fileRecord.rows.length === 0) {
      return ApiResponse.notFound(res, 'File not found');
    }

    const file = fileRecord.rows[0];
    const filePath = path.join(UPLOAD_DIR, file.storage_key);

    // Delete from storage
    try {
      await fs.unlink(filePath);
    } catch (error) {
      logger.warn('File not found on disk:', filePath);
    }

    // Delete record
    await query('DELETE FROM media_files WHERE id = $1', [fileId]);

    return ApiResponse.success(res, null, 'File deleted');

  } catch (error) {
    logger.error('Delete file error:', error);
    return ApiResponse.serverError(res);
  }
};

// Get user's files
const getUserFiles = async (req, res) => {
  try {
    const { type, limit = 50, offset = 0 } = req.query;

    let queryText = `
      SELECT id, type, original_name, mime_type, size_bytes, created_at
      FROM media_files
      WHERE uploader_id = $1
    `;
    const params = [req.user.id];
    let paramCount = 2;

    if (type) {
      queryText += ` AND type = $${paramCount++}`;
      params.push(type);
    }

    queryText += ` ORDER BY created_at DESC LIMIT $${paramCount++} OFFSET $${paramCount}`;
    params.push(parseInt(limit), parseInt(offset));

    const result = await query(queryText, params);

    return ApiResponse.success(res, result.rows.map(f => ({
      id: f.id,
      type: f.type,
      name: f.original_name,
      mimeType: f.mime_type,
      size: f.size_bytes,
      url: `/api/v1/media/files/${f.storage_key}`,
      createdAt: f.created_at
    })));

  } catch (error) {
    logger.error('Get user files error:', error);
    return ApiResponse.serverError(res);
  }
};

module.exports = {
  getUploadUrl,
  uploadFile,
  getFile,
  deleteFile,
  getUserFiles
};
