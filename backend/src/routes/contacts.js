const express = require('express');
const router = express.Router();
const { body, param, query: queryValidator } = require('express-validator');

const contactController = require('../controllers/contactController');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

router.use(authenticate);

// Get contacts
router.get('/', [
  queryValidator('favorites').optional().isBoolean(),
  queryValidator('blocked').optional().isBoolean()
], validate, contactController.getContacts);

// Add contact
router.post('/', [
  body('userId').isUUID(),
  body('nickname').optional().trim().isLength({ max: 100 })
], validate, contactController.addContact);

// Sync contacts
router.post('/sync', [
  body('phones').isArray({ min: 1, max: 1000 }),
  body('phones.*').trim().notEmpty()
], validate, contactController.syncContacts);

// Update contact
router.patch('/:contactId', [
  param('contactId').isUUID(),
  body('nickname').optional().trim().isLength({ max: 100 }),
  body('isFavorite').optional().isBoolean()
], validate, contactController.updateContact);

// Delete contact
router.delete('/:contactId', [
  param('contactId').isUUID()
], validate, contactController.deleteContact);

// Block/Unblock
router.get('/blocked', contactController.getBlockedUsers);

router.post('/block/:userId', [
  param('userId').isUUID()
], validate, contactController.blockUser);

router.post('/unblock/:userId', [
  param('userId').isUUID()
], validate, contactController.unblockUser);

module.exports = router;
