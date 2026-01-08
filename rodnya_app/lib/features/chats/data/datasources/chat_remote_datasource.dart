import 'package:dio/dio.dart';
import '../models/chat_model.dart';

class ChatRemoteDatasource {
  final Dio _dio;

  ChatRemoteDatasource(this._dio);

  Future<List<ChatModel>> getChats() async {
    final response = await _dio.get('/chats');
    final List<dynamic> data = response.data['data'] ?? [];
    return data.map((e) => ChatModel.fromJson(e)).toList();
  }

  Future<ChatModel> getChat(String chatId) async {
    final response = await _dio.get('/chats/$chatId');
    return ChatModel.fromJson(response.data['data']);
  }

  Future<ChatModel> createDirectChat(String userId) async {
    final response = await _dio.post('/chats/direct', data: {'user_id': userId});
    return ChatModel.fromJson(response.data['data']);
  }

  Future<ChatModel> createGroupChat({required String name, String? description, List<String>? memberIds}) async {
    final response = await _dio.post('/chats/group', data: {'name': name, 'description': description, 'member_ids': memberIds});
    return ChatModel.fromJson(response.data['data']);
  }

  Future<void> updateChatSettings({required String chatId, bool? isMuted, bool? isPinned}) async {
    await _dio.patch('/chats/$chatId/settings', data: {
      if (isMuted != null) 'is_muted': isMuted,
      if (isPinned != null) 'is_pinned': isPinned,
    });
  }

  Future<void> markChatAsRead(String chatId) async {
    await _dio.post('/chats/$chatId/read');
  }

  Future<List<MessageModel>> getMessages({required String chatId, int limit = 50, int offset = 0}) async {
    final response = await _dio.get('/messages/chat/$chatId', queryParameters: {'limit': limit, 'offset': offset});
    final List<dynamic> data = response.data['data'] ?? [];
    return data.map((e) => MessageModel.fromJson(e)).toList();
  }

  Future<MessageModel> sendMessage({required String chatId, required String type, String? content,
    String? mediaUrl, String? thumbnailUrl, String? fileName, int? fileSize, int? duration, String? replyToId}) async {
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
    return MessageModel.fromJson(response.data['data']);
  }

  Future<MessageModel> editMessage({required String messageId, required String chatId, required String content}) async {
    final response = await _dio.patch('/messages/$messageId/chat/$chatId', data: {'content': content});
    return MessageModel.fromJson(response.data['data']);
  }

  Future<void> deleteMessage({required String messageId, required String chatId}) async {
    await _dio.delete('/messages/$messageId/chat/$chatId');
  }

  Future<List<MessageModel>> searchMessages({required String chatId, required String query, int limit = 20}) async {
    final response = await _dio.get('/messages/chat/$chatId/search', queryParameters: {'q': query, 'limit': limit});
    final List<dynamic> data = response.data['data'] ?? [];
    return data.map((e) => MessageModel.fromJson(e)).toList();
  }

  Future<void> addGroupMember(String chatId, String userId) async {
    await _dio.post('/chats/$chatId/members', data: {'user_id': userId});
  }

  Future<void> removeGroupMember(String chatId, String userId) async {
    await _dio.delete('/chats/$chatId/members/$userId');
  }

  Future<ChatModel> updateGroup({required String chatId, String? name, String? description, String? avatarUrl}) async {
    final response = await _dio.patch('/chats/$chatId', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
    return ChatModel.fromJson(response.data['data']);
  }
}
