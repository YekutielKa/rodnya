import 'package:dio/dio.dart';
import '../models/chat_model.dart';

class ChatRemoteDatasource {
  final Dio _dio;

  ChatRemoteDatasource(this._dio);

  // =====================
  // CHATS
  // =====================

  Future<List<ChatModel>> getChats({int page = 1, int limit = 20}) async {
    final response = await _dio.get('/chats', queryParameters: {
      'page': page,
      'limit': limit,
    });
    final List<dynamic> data = response.data['data'] ?? response.data ?? [];
    print('=== GET CHATS RESPONSE: ${response.data} ===');
    return data.map((e) => ChatModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChatModel> getChat(String chatId) async {
    print('=== GET CHAT REQUEST: $chatId ===');
    final response = await _dio.get('/chats/$chatId');
    final data = response.data['data'] ?? response.data;
    print('=== GET CHAT RESPONSE: $data ===');
    return ChatModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ChatModel> createDirectChat(String userId) async {
    final response = await _dio.post('/chats/direct', data: {'user_id': userId});
    final data = response.data['data'] ?? response.data;
    print('=== GET CHAT RESPONSE: $data ===');
    return ChatModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ChatModel> createGroupChat({
    required String name,
    String? description,
    List<String>? memberIds,
  }) async {
    final response = await _dio.post('/chats/group', data: {
      'name': name,
      if (description != null) 'description': description,
      if (memberIds != null) 'member_ids': memberIds,
    });
    final data = response.data['data'] ?? response.data;
    print('=== GET CHAT RESPONSE: $data ===');
    return ChatModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> updateChatSettings({
    required String chatId,
    bool? isMuted,
    bool? isPinned,
  }) async {
    await _dio.patch('/chats/$chatId/settings', data: {
      if (isMuted != null) 'is_muted': isMuted,
      if (isPinned != null) 'is_pinned': isPinned,
    });
  }

  Future<void> markChatAsRead(String chatId) async {
    await _dio.post('/chats/$chatId/read');
  }

  // =====================
  // MESSAGES
  // =====================

  Future<List<MessageModel>> getMessages({
    required String chatId,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      '/messages/chat/$chatId',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final List<dynamic> data = response.data['data'] ?? response.data ?? [];
    print('=== GET CHATS RESPONSE: ${response.data} ===');
    return data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MessageModel> sendMessage({
    required String chatId,
    required String type,
    String? content,
    String? mediaUrl,
    String? thumbnailUrl,
    String? fileName,
    int? fileSize,
    int? duration,
    String? replyToId,
  }) async {
    final response = await _dio.post('/messages/chat/$chatId', data: {
      'type': type,
      if (content != null) 'content': content,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (duration != null) 'duration': duration,
      if (replyToId != null) 'reply_to_id': replyToId,
    });
    final data = response.data['data'] ?? response.data;
    print('=== GET CHAT RESPONSE: $data ===');
    return MessageModel.fromJson(data as Map<String, dynamic>);
  }

  Future<MessageModel> editMessage({
    required String messageId,
    required String chatId,
    required String content,
  }) async {
    final response = await _dio.patch(
      '/messages/$messageId/chat/$chatId',
      data: {'content': content},
    );
    final data = response.data['data'] ?? response.data;
    print('=== GET CHAT RESPONSE: $data ===');
    return MessageModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteMessage({
    required String messageId,
    required String chatId,
  }) async {
    await _dio.delete('/messages/$messageId/chat/$chatId');
  }

  Future<List<MessageModel>> searchMessages({
    required String chatId,
    required String query,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/messages/chat/$chatId/search',
      queryParameters: {'q': query, 'limit': limit},
    );
    final List<dynamic> data = response.data['data'] ?? response.data ?? [];
    print('=== GET CHATS RESPONSE: ${response.data} ===');
    return data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // =====================
  // GROUP MANAGEMENT
  // =====================

  Future<void> addGroupMember(String chatId, String userId) async {
    await _dio.post('/chats/$chatId/members', data: {'user_id': userId});
  }

  Future<void> removeGroupMember(String chatId, String userId) async {
    await _dio.delete('/chats/$chatId/members/$userId');
  }

  Future<ChatModel> updateGroup({
    required String chatId,
    String? name,
    String? description,
    String? avatarUrl,
  }) async {
    final response = await _dio.patch('/chats/$chatId', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
    final data = response.data['data'] ?? response.data;
    print('=== GET CHAT RESPONSE: $data ===');
    return ChatModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> leaveGroup(String chatId) async {
    await _dio.delete('/chats/$chatId/members/me');
  }
}
