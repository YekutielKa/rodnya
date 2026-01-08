import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../../features/chats/data/models/chat_model.dart';

class SocketService {
  io.Socket? _socket;
  String? _userId;
  final _storage = const FlutterSecureStorage();
  
  final List<Function(MessageModel)> _messageListeners = [];
  final List<Function(String messageId, String status, String? userId)> _statusListeners = [];
  final List<Function(String chatId, String userId, String userName)> _typingStartListeners = [];
  final List<Function(String chatId, String userId)> _typingStopListeners = [];
  final List<Function(String userId, String status, String? lastSeen)> _presenceListeners = [];
  final List<Function(Map<String, dynamic>)> _callListeners = [];

  bool get isConnected => _socket?.connected ?? false;
  String? get userId => _userId;

  Future<void> connect(String userId) async {
    _userId = userId;
    final token = await _storage.read(key: 'access_token');
    _socket = io.io(
      AppConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setAuth({'token': token})
          .build(),
    );
    _setupListeners();
    _socket!.connect();
  }

  void _setupListeners() {
    _socket!.onConnect((_) => print('Socket connected'));
    _socket!.onDisconnect((_) => print('Socket disconnected'));
    _socket!.onConnectError((error) => print('Socket error: $error'));

    _socket!.on('message:new', (data) {
      try {
        final messageData = data is Map<String, dynamic> ? data['message'] ?? data : data;
        final message = MessageModel.fromJson(messageData);
        for (final listener in _messageListeners) listener(message);
        if (message.senderId != _userId) sendDelivered(message.id, message.chatId);
      } catch (e) { print('Error parsing message: $e'); }
    });

    _socket!.on('message:status', (data) {
      final messageId = data['messageId'] as String?;
      final status = data['status'] as String?;
      final uId = data['userId'] as String?;
      if (messageId != null && status != null) {
        for (final listener in _statusListeners) listener(messageId, status, uId);
      }
    });

    _socket!.on('typing:start', (data) {
      final chatId = data['chatId'] as String?;
      final uId = data['userId'] as String?;
      final userName = data['userName'] as String? ?? 'Пользователь';
      if (chatId != null && uId != null && uId != _userId) {
        for (final listener in _typingStartListeners) listener(chatId, uId, userName);
      }
    });

    _socket!.on('typing:stop', (data) {
      final chatId = data['chatId'] as String?;
      final uId = data['userId'] as String?;
      if (chatId != null && uId != null) {
        for (final listener in _typingStopListeners) listener(chatId, uId);
      }
    });

    _socket!.on('presence:update', (data) {
      final uId = data['userId'] as String?;
      final status = data['status'] as String? ?? 'offline';
      final lastSeen = data['lastSeen'] as String?;
      if (uId != null) {
        for (final listener in _presenceListeners) listener(uId, status, lastSeen);
      }
    });

    _socket!.on('call:incoming', (data) => _notifyCall({...data, 'event': 'incoming'}));
    _socket!.on('call:accepted', (data) => _notifyCall({...data, 'event': 'accepted'}));
    _socket!.on('call:rejected', (data) => _notifyCall({...data, 'event': 'rejected'}));
    _socket!.on('call:ended', (data) => _notifyCall({...data, 'event': 'ended'}));
    _socket!.on('call:signal', (data) => _notifyCall({...data, 'event': 'signal'}));
    _socket!.on('call:ice-candidate', (data) => _notifyCall({...data, 'event': 'ice-candidate'}));
  }

  void _notifyCall(Map<String, dynamic> data) {
    for (final listener in _callListeners) listener(data);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _messageListeners.clear();
    _statusListeners.clear();
    _typingStartListeners.clear();
    _typingStopListeners.clear();
    _presenceListeners.clear();
    _callListeners.clear();
  }

  void onNewMessage(Function(MessageModel) callback) => _messageListeners.add(callback);
  void removeMessageListener(Function(MessageModel) callback) => _messageListeners.remove(callback);
  void onMessageStatus(Function(String, String, String?) callback) => _statusListeners.add(callback);
  void onTypingStart(Function(String, String, String) callback) => _typingStartListeners.add(callback);
  void onTypingStop(Function(String, String) callback) => _typingStopListeners.add(callback);
  void onPresenceUpdate(Function(String, String, String?) callback) => _presenceListeners.add(callback);
  void onCall(Function(Map<String, dynamic>) callback) => _callListeners.add(callback);

  void sendTypingStart(String chatId) => _socket?.emit('typing:start', {'chatId': chatId});
  void sendTypingStop(String chatId) => _socket?.emit('typing:stop', {'chatId': chatId});
  void sendDelivered(String messageId, String chatId) => _socket?.emit('message:delivered', {'messageId': messageId, 'chatId': chatId});
  void sendRead(String messageId, String chatId) => _socket?.emit('message:read', {'messageId': messageId, 'chatId': chatId});
  void joinChat(String chatId) => _socket?.emit('chat:join', {'chatId': chatId});

  void initiateCall({required String recipientId, required String callType, required String callId}) {
    _socket?.emit('call:initiate', {'recipientId': recipientId, 'callType': callType, 'callId': callId});
  }
  void acceptCall(String callId) => _socket?.emit('call:accept', {'callId': callId});
  void rejectCall(String callId) => _socket?.emit('call:reject', {'callId': callId});
  void endCall(String callId) => _socket?.emit('call:end', {'callId': callId});
  void sendSignal(String callId, String recipientId, Map<String, dynamic> signal) {
    _socket?.emit('call:signal', {'callId': callId, 'targetUserId': recipientId, 'signal': signal});
  }
  void sendIceCandidate(String callId, String recipientId, Map<String, dynamic> candidate) {
    _socket?.emit('call:ice-candidate', {'callId': callId, 'targetUserId': recipientId, 'candidate': candidate});
  }
}
