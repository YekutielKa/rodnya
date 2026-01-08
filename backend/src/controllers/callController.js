const { query, transaction } = require('../config/database');
const { pubsub } = require('../config/redis');
const { generateTurnCredentials } = require('../utils/jwt');
const ApiResponse = require('../utils/response');
const logger = require('../utils/logger');

// Initiate call
const initiateCall = async (req, res) => {
  try {
    const { chatId, type } = req.body;

    // Check membership
    const memberCheck = await query(
      `SELECT cm.user_id, c.type as chat_type FROM chat_members cm
       JOIN chats c ON c.id = cm.chat_id
       WHERE cm.chat_id = $1`,
      [chatId]
    );

    if (memberCheck.rows.length === 0) {
      return ApiResponse.notFound(res, 'Chat not found');
    }

    const isMember = memberCheck.rows.some(m => m.user_id === req.user.id);
    if (!isMember) {
      return ApiResponse.forbidden(res, 'Not a member of this chat');
    }

    // Create call record
    const callResult = await query(
      `INSERT INTO calls (chat_id, caller_id, type, status)
       VALUES ($1, $2, $3, 'initiated')
       RETURNING id`,
      [chatId, req.user.id, type]
    );

    const callId = callResult.rows[0].id;

    // Add participants
    const otherMembers = memberCheck.rows.filter(m => m.user_id !== req.user.id);
    
    for (const member of otherMembers) {
      await query(
        `INSERT INTO call_participants (call_id, user_id, status)
         VALUES ($1, $2, 'invited')`,
        [callId, member.user_id]
      );

      // Notify participant
      await pubsub.publish(`user:${member.user_id}`, {
        type: 'incoming_call',
        callId,
        chatId,
        callType: type,
        caller: {
          id: req.user.id,
          name: req.user.name,
          avatarUrl: req.user.avatar_url
        }
      });
    }

    // Add caller as participant
    await query(
      `INSERT INTO call_participants (call_id, user_id, status, joined_at)
       VALUES ($1, $2, 'accepted', NOW())`,
      [callId, req.user.id]
    );

    // Generate TURN credentials
    const turnCredentials = generateTurnCredentials(req.user.id);

    return ApiResponse.created(res, {
      callId,
      turnCredentials
    });

  } catch (error) {
    logger.error('Initiate call error:', error);
    return ApiResponse.serverError(res);
  }
};

// Accept call
const acceptCall = async (req, res) => {
  try {
    const { callId } = req.params;

    // Check if invited
    const participantCheck = await query(
      `SELECT cp.status, c.status as call_status, c.chat_id
       FROM call_participants cp
       JOIN calls c ON c.id = cp.call_id
       WHERE cp.call_id = $1 AND cp.user_id = $2`,
      [callId, req.user.id]
    );

    if (participantCheck.rows.length === 0) {
      return ApiResponse.notFound(res, 'Call not found');
    }

    const { status, call_status, chat_id } = participantCheck.rows[0];

    if (call_status === 'ended') {
      return ApiResponse.error(res, 'Call already ended', 400);
    }

    // Update participant status
    await query(
      `UPDATE call_participants SET status = 'accepted', joined_at = NOW()
       WHERE call_id = $1 AND user_id = $2`,
      [callId, req.user.id]
    );

    // Update call status
    await query(
      `UPDATE calls SET status = 'accepted', started_at = NOW()
       WHERE id = $1 AND status = 'initiated'`,
      [callId]
    );

    // Notify others
    await pubsub.publish(`call:${callId}`, {
      type: 'participant_joined',
      userId: req.user.id,
      userName: req.user.name
    });

    // Generate TURN credentials
    const turnCredentials = generateTurnCredentials(req.user.id);

    return ApiResponse.success(res, { turnCredentials });

  } catch (error) {
    logger.error('Accept call error:', error);
    return ApiResponse.serverError(res);
  }
};

// Reject call
const rejectCall = async (req, res) => {
  try {
    const { callId } = req.params;
    const { reason = 'rejected' } = req.body;

    await query(
      `UPDATE call_participants SET status = 'rejected'
       WHERE call_id = $1 AND user_id = $2`,
      [callId, req.user.id]
    );

    // Check if all rejected
    const participantsCheck = await query(
      `SELECT COUNT(*) as total, 
              COUNT(*) FILTER (WHERE status IN ('rejected', 'left')) as rejected
       FROM call_participants 
       WHERE call_id = $1 AND user_id != (SELECT caller_id FROM calls WHERE id = $1)`,
      [callId]
    );

    const { total, rejected } = participantsCheck.rows[0];

    if (parseInt(total) === parseInt(rejected)) {
      await query(
        `UPDATE calls SET status = 'rejected', ended_at = NOW(), end_reason = $2 WHERE id = $1`,
        [callId, reason]
      );
    }

    // Notify caller
    await pubsub.publish(`call:${callId}`, {
      type: 'call_rejected',
      userId: req.user.id,
      reason
    });

    return ApiResponse.success(res, null, 'Call rejected');

  } catch (error) {
    logger.error('Reject call error:', error);
    return ApiResponse.serverError(res);
  }
};

// End call
const endCall = async (req, res) => {
  try {
    const { callId } = req.params;

    // Get call info
    const callInfo = await query(
      `SELECT c.*, cp.status as participant_status
       FROM calls c
       JOIN call_participants cp ON cp.call_id = c.id AND cp.user_id = $2
       WHERE c.id = $1`,
      [callId, req.user.id]
    );

    if (callInfo.rows.length === 0) {
      return ApiResponse.notFound(res, 'Call not found');
    }

    const call = callInfo.rows[0];

    // Update participant
    await query(
      `UPDATE call_participants SET status = 'left', left_at = NOW()
       WHERE call_id = $1 AND user_id = $2`,
      [callId, req.user.id]
    );

    // Check if call should end (all participants left)
    const activeParticipants = await query(
      `SELECT COUNT(*) FROM call_participants 
       WHERE call_id = $1 AND status = 'accepted'`,
      [callId]
    );

    if (parseInt(activeParticipants.rows[0].count) <= 1) {
      // Calculate duration
      let duration = null;
      if (call.started_at) {
        duration = Math.floor((Date.now() - new Date(call.started_at).getTime()) / 1000);
      }

      await query(
        `UPDATE calls SET status = 'ended', ended_at = NOW(), duration_seconds = $2
         WHERE id = $1`,
        [callId, duration]
      );

      // Create call message
      await query(
        `INSERT INTO messages (chat_id, sender_id, type, content)
         VALUES ($1, $2, 'call', $3)`,
        [call.chat_id, call.caller_id, JSON.stringify({
          callId,
          type: call.type,
          duration,
          status: 'ended'
        })]
      );
    }

    // Notify others
    await pubsub.publish(`call:${callId}`, {
      type: 'participant_left',
      userId: req.user.id
    });

    return ApiResponse.success(res, null, 'Left call');

  } catch (error) {
    logger.error('End call error:', error);
    return ApiResponse.serverError(res);
  }
};

// Get call history
const getCallHistory = async (req, res) => {
  try {
    const { limit = 50, offset = 0 } = req.query;

    const result = await query(
      `SELECT c.*, 
        u.name as caller_name, u.avatar_url as caller_avatar,
        (SELECT json_agg(json_build_object('id', pu.id, 'name', pu.name))
         FROM call_participants cp
         JOIN users pu ON pu.id = cp.user_id
         WHERE cp.call_id = c.id) as participants
       FROM calls c
       JOIN users u ON u.id = c.caller_id
       WHERE c.chat_id IN (SELECT chat_id FROM chat_members WHERE user_id = $1)
       ORDER BY c.created_at DESC
       LIMIT $2 OFFSET $3`,
      [req.user.id, parseInt(limit), parseInt(offset)]
    );

    const calls = result.rows.map(c => ({
      id: c.id,
      chatId: c.chat_id,
      type: c.type,
      status: c.status,
      caller: {
        id: c.caller_id,
        name: c.caller_name,
        avatarUrl: c.caller_avatar
      },
      participants: c.participants,
      duration: c.duration_seconds,
      startedAt: c.started_at,
      endedAt: c.ended_at,
      createdAt: c.created_at,
      isMissed: c.status === 'missed' || (c.status === 'rejected' && c.caller_id !== req.user.id)
    }));

    return ApiResponse.success(res, calls);

  } catch (error) {
    logger.error('Get call history error:', error);
    return ApiResponse.serverError(res);
  }
};

// Get TURN credentials
const getTurnCredentials = async (req, res) => {
  try {
    const credentials = generateTurnCredentials(req.user.id);
    return ApiResponse.success(res, credentials);
  } catch (error) {
    logger.error('Get TURN credentials error:', error);
    return ApiResponse.serverError(res);
  }
};

// Send WebRTC signal
const sendSignal = async (req, res) => {
  try {
    const { callId } = req.params;
    const { targetUserId, signal } = req.body;

    // Verify participation
    const check = await query(
      'SELECT id FROM call_participants WHERE call_id = $1 AND user_id = $2',
      [callId, req.user.id]
    );

    if (check.rows.length === 0) {
      return ApiResponse.forbidden(res, 'Not in this call');
    }

    // Send signal to target user
    await pubsub.publish(`user:${targetUserId}`, {
      type: 'webrtc_signal',
      callId,
      fromUserId: req.user.id,
      signal
    });

    return ApiResponse.success(res);

  } catch (error) {
    logger.error('Send signal error:', error);
    return ApiResponse.serverError(res);
  }
};

module.exports = {
  initiateCall,
  acceptCall,
  rejectCall,
  endCall,
  getCallHistory,
  getTurnCredentials,
  sendSignal
};
