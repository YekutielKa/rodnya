import 'package:dio/dio.dart';
import '../models/chat_model.dart';

class ChatRemoteDatasource {
  final Dio _dio;

  ChatRemoteDatasource(this._dio);

  // ============================================================================
  // CHATS
  // ============================================================================

  /// Get all chats for current user
  Future<List<ChatModel>> getChats({int page = 1}) async {
    final response = await _dio.get('/chats', queryParameters: {'page': page});
    final data = response.data['data'] as List<dynamic>;
    return data.map((json) => ChatModel.fromJson(json)).toList();
  }

  /// Get single chat by ID
  Future<ChatModel> getChat(String chatId) async {
    final response = await _dio.get('/chats/$chatId');
    return ChatModel.fromJson(response.data['data']);
  }

  /// Create or get existing direct chat with user
  Future<Map<String, dynamic>> getOrCreateDirectChat(String otherUserId) async {
    final response = await _dio.post('/chats/direct', data: {
      'otherUserId': otherUserId,
    });
    return {
      'chatId': response.data['data']['chatId'] ?? response.data['data']['id'],
      'isNew': response.data['data']['isNew'] ?? false,
    };
  }

  /// Create direct chat (alias for getOrCreateDirectChat)
  Future<ChatModel> createDirectChat(String otherUserId) async {
    final result = await getOrCreateDirectChat(otherUserId);
    return getChat(result['chatId']);
  }

  /// Create group chat
  Future<ChatModel> createGroupChat({
    required String name,
    required List<String> participantIds,
    String? description,
    String? avatarUrl,
  }) async {
    final response = await _dio.post('/chats/group', data: {
      'name': name,
      'memberIds': participantIds,
      'description': description,
      'avatarUrl': avatarUrl,
    });
    return ChatModel.fromJson(response.data['data']);
  }

  /// Update chat settings
  Future<ChatModel> updateChat(String chatId, {
    String? name,
    String? description,
    String? avatarUrl,
  }) async {
    final response = await _dio.patch('/chats/$chatId', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    return ChatModel.fromJson(response.data['data']);
  }

  /// Mark chat as read
  Future<void> markAsRead(String chatId) async {
    await _dio.post('/chats/$chatId/read');
  }

  /// Mute/unmute chat
  Future<void> muteChat(String chatId, bool muted) async {
    await _dio.patch('/chats/$chatId/settings', data: {
      'muted': muted,
    });
  }

  /// Pin/unpin chat
  Future<void> pinChat(String chatId, bool pinned) async {
    await _dio.patch('/chats/$chatId/settings', data: {
      'pinned': pinned,
    });
  }

  /// Leave chat (for group chats)
  Future<void> leaveChat(String chatId) async {
    await _dio.post('/chats/$chatId/leave');
  }

  /// Delete chat
  Future<void> deleteChat(String chatId) async {
    await _dio.delete('/chats/$chatId');
  }

  // ============================================================================
  // MESSAGES
  // ============================================================================

  /// Get messages for chat with pagination
  /// Messages are returned oldest first for proper ListView display with reverse: true
  Future<List<MessageModel>> getMessages(
    String chatId, {
    String? before,
    String? after,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/messages/chat/$chatId',
      queryParameters: {
        if (before != null) 'before': before,
        if (after != null) 'after': after,
        'limit': limit,
      },
    );
    
    final data = response.data['data'];
    final List<dynamic> messages = data is List ? data : (data['messages'] ?? []);
    return messages.map((json) => MessageModel.fromJson(json)).toList();
  }

  /// Send text message
  Future<MessageModel> sendMessage({
    required String chatId,
    required String content,
    String? replyToId,
  }) async {
    final response = await _dio.post(
      '/messages/chat/$chatId',
      data: {
        'type': 'text',
        'content': content,
        if (replyToId != null) 'replyToId': replyToId,
      },
    );
    return MessageModel.fromJson(response.data['data']);
  }

  /// Send media message (image, video, audio, file)
  Future<MessageModel> sendMediaMessage({
    required String chatId,
    required MessageType type,
    required String mediaUrl,
    String? content,
    String? thumbnailUrl,
    String? fileName,
    int? fileSize,
    int? duration,
    String? replyToId,
  }) async {
    final response = await _dio.post(
      '/messages/chat/$chatId',
      data: {
        'type': type.name,
        'content': content,
        'mediaUrl': mediaUrl,
        'thumbnailUrl': thumbnailUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'duration': duration,
        if (replyToId != null) 'replyToId': replyToId,
      },
    );
    return MessageModel.fromJson(response.data['data']);
  }

  /// Send voice message
  Future<MessageModel> sendVoiceMessage({
    required String chatId,
    required String audioUrl,
    required int duration,
    String? replyToId,
  }) async {
    final response = await _dio.post(
      '/messages/chat/$chatId',
      data: {
        'type': 'voice',
        'mediaUrl': audioUrl,
        'duration': duration,
        if (replyToId != null) 'replyToId': replyToId,
      },
    );
    return MessageModel.fromJson(response.data['data']);
  }

  /// Edit message
  Future<MessageModel> editMessage(String messageId, String newContent) async {
    final response = await _dio.patch(
      '/messages/$messageId',
      data: {'content': newContent},
    );
    return MessageModel.fromJson(response.data['data']);
  }

  /// Delete message
  Future<void> deleteMessage(String chatId, String messageId) async {
    await _dio.delete('/messages/$messageId/chat/$chatId');
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    await _dio.post('/messages/$messageId/read');
  }

  // ============================================================================
  // GROUP MEMBERS
  // ============================================================================

  /// Add member to group chat
  Future<void> addMember(String chatId, String userId) async {
    await _dio.post('/chats/$chatId/members', data: {
      'userId': userId,
    });
  }

  /// Remove member from group chat
  Future<void> removeMember(String chatId, String userId) async {
    await _dio.delete('/chats/$chatId/members/$userId');
  }

  /// Make member admin
  Future<void> makeMemberAdmin(String chatId, String userId) async {
    await _dio.patch('/chats/$chatId/members/$userId', data: {
      'role': 'admin',
    });
  }

  /// Remove admin privileges
  Future<void> removeMemberAdmin(String chatId, String userId) async {
    await _dio.patch('/chats/$chatId/members/$userId', data: {
      'role': 'member',
    });
  }

  // ============================================================================
  // MEDIA UPLOAD
  // ============================================================================

  /// Upload media file and get URL
  Future<Map<String, dynamic>> uploadMedia(
    String filePath,
    String fileName,
    String mimeType,
  ) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: DioMediaType.parse(mimeType),
      ),
    });

    final response = await _dio.post('/media/upload', data: formData);
    return {
      'url': response.data['data']['url'],
      'thumbnailUrl': response.data['data']['thumbnailUrl'],
      'fileSize': response.data['data']['fileSize'],
    };
  }

  // ============================================================================
  // TYPING INDICATORS
  // ============================================================================

  /// Send typing indicator
  Future<void> sendTyping(String chatId) async {
    await _dio.post('/chats/$chatId/typing');
  }

  /// Stop typing indicator
  Future<void> stopTyping(String chatId) async {
    await _dio.delete('/chats/$chatId/typing');
  }
}
