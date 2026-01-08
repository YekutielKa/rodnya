import 'package:dio/dio.dart';
import '../models/chat_model.dart';

class ChatRemoteDatasource {
  final Dio _dio;

  ChatRemoteDatasource(this._dio);

  Future<List<ChatModel>> getChats({int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get('/chats', queryParameters: {
        'page': page,
        'limit': limit,
      });
      
      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        final chats = (data['data'] as List<dynamic>?) ?? [];
        return chats.map((c) => ChatModel.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting chats: $e');
      rethrow;
    }
  }

  Future<ChatModel> getChat(String chatId) async {
    try {
      final response = await _dio.get('/chats/$chatId');
      
      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        return ChatModel.fromJson(data['data']);
      }
      throw Exception('Chat not found');
    } catch (e) {
      print('Error getting chat: $e');
      rethrow;
    }
  }

  Future<ChatModel> createDirectChat(String userId) async {
    try {
      final response = await _dio.post('/chats/direct', data: {
        'userId': userId,
      });
      
      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        return ChatModel.fromJson(data['data']);
      }
      throw Exception('Failed to create chat');
    } catch (e) {
      print('Error creating chat: $e');
      rethrow;
    }
  }

  Future<ChatModel> createGroupChat({
    required String name,
    required List<String> participantIds,
    String? avatarUrl,
  }) async {
    try {
      final response = await _dio.post('/chats/group', data: {
        'name': name,
        'participantIds': participantIds,
        'avatarUrl': avatarUrl,
      });
      
      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        return ChatModel.fromJson(data['data']);
      }
      throw Exception('Failed to create group');
    } catch (e) {
      print('Error creating group: $e');
      rethrow;
    }
  }

  Future<List<MessageModel>> getMessages(
    String chatId, {
    int page = 1,
    int limit = 50,
    String? before,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit,
      };
      if (before != null) {
        queryParams['before'] = before;
      }

      final response = await _dio.get(
        '/chats/$chatId/messages',
        queryParameters: queryParams,
      );
      
      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        final messages = (data['data']['messages'] as List<dynamic>?) ?? [];
        return messages.map((m) => MessageModel.fromJson(m)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting messages: $e');
      rethrow;
    }
  }

  Future<MessageModel> sendMessage({
    required String chatId,
    required String type,
    String? content,
    String? mediaUrl,
    String? fileName,
    int? fileSize,
    int? duration,
    String? replyToId,
  }) async {
    try {
      final response = await _dio.post('/chats/$chatId/messages', data: {
        'type': type,
        'content': content,
        'mediaUrl': mediaUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'duration': duration,
        'replyTo': replyToId,
      });
      
      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        return MessageModel.fromJson(data['data']);
      }
      throw Exception('Failed to send message');
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String chatId) async {
    try {
      await _dio.post('/chats/$chatId/read');
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _dio.delete('/chats/$chatId/messages/$messageId');
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }

  Future<void> leaveChat(String chatId) async {
    try {
      await _dio.post('/chats/$chatId/leave');
    } catch (e) {
      print('Error leaving chat: $e');
      rethrow;
    }
  }
}
