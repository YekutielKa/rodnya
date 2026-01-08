import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

class SocketService {
  io.Socket? _socket;
  final _storage = const FlutterSecureStorage();
  
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _callController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;
  Stream<Map<String, dynamic>> get callStream => _callController.stream;
  
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    _socket = io.io(
      AppConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!.onConnect((_) {
      print('Socket connected');
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket!.onError((error) {
      print('Socket error: $error');
    });

    // Message events
    _socket!.on('new_message', (data) {
      _messageController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message_edited', (data) {
      _messageController.add({
        'type': 'edited',
        ...Map<String, dynamic>.from(data),
      });
    });

    _socket!.on('message_deleted', (data) {
      _messageController.add({
        'type': 'deleted',
        ...Map<String, dynamic>.from(data),
      });
    });

    _socket!.on('message:status', (data) {
      _messageController.add({
        'type': 'status',
        ...Map<String, dynamic>.from(data),
      });
    });

    // Typing events
    _socket!.on('typing:start', (data) {
      _typingController.add({
        'isTyping': true,
        ...Map<String, dynamic>.from(data),
      });
    });

    _socket!.on('typing:stop', (data) {
      _typingController.add({
        'isTyping': false,
        ...Map<String, dynamic>.from(data),
      });
    });

    // Presence events
    _socket!.on('presence:update', (data) {
      _presenceController.add(Map<String, dynamic>.from(data));
    });

    // Call events
    _socket!.on('incoming_call', (data) {
      _callController.add({
        'type': 'incoming',
        ...Map<String, dynamic>.from(data),
      });
    });

    _socket!.on('call:signal', (data) {
      _callController.add({
        'type': 'signal',
        ...Map<String, dynamic>.from(data),
      });
    });

    _socket!.on('call:ice-candidate', (data) {
      _callController.add({
        'type': 'ice-candidate',
        ...Map<String, dynamic>.from(data),
      });
    });

    _socket!.on('participant_joined', (data) {
      _callController.add({
        'type': 'participant_joined',
        ...Map<String, dynamic>.from(data),
      });
    });

    _socket!.on('participant_left', (data) {
      _callController.add({
        'type': 'participant_left',
        ...Map<String, dynamic>.from(data),
      });
    });

    _socket!.on('call_rejected', (data) {
      _callController.add({
        'type': 'rejected',
        ...Map<String, dynamic>.from(data),
      });
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  // Typing
  void startTyping(String chatId) {
    _socket?.emit('typing:start', {'chatId': chatId});
  }

  void stopTyping(String chatId) {
    _socket?.emit('typing:stop', {'chatId': chatId});
  }

  // Message read
  void markMessageRead(String chatId, String messageId) {
    _socket?.emit('message:read', {
      'chatId': chatId,
      'messageId': messageId,
    });
  }

  // Presence
  void updatePresence(String status) {
    _socket?.emit('presence:update', {'status': status});
  }

  // WebRTC signaling
  void sendCallSignal(String callId, String targetUserId, Map<String, dynamic> signal) {
    _socket?.emit('call:signal', {
      'callId': callId,
      'targetUserId': targetUserId,
      'signal': signal,
    });
  }

  void sendIceCandidate(String callId, String targetUserId, Map<String, dynamic> candidate) {
    _socket?.emit('call:ice-candidate', {
      'callId': callId,
      'targetUserId': targetUserId,
      'candidate': candidate,
    });
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _presenceController.close();
    _callController.close();
  }
}
