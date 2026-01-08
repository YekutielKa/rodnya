import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../../features/chats/data/models/chat_model.dart';

class SocketService {
  io.Socket? _socket;
  String? _userId;
  final _storage = const FlutterSecureStorage();
  
  final List<Function(MessageModel)> _messageListeners = [];
  final List<Function(String visitorId, bool isTyping)> _typingListeners = [];
  final List<Function(String visitorId, bool isOnline)> _presenceListeners = [];
  final List<Function(Map<String, dynamic>)> _callListeners = [];

  Future<void> connect(String userId) async {
    _userId = userId;
    
    // Get access token for authentication
    final token = await _storage.read(key: 'access_token');
    
    _socket = io.io(
      AppConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      print('Socket connected');
      _socket!.emit('user:online', {'userId': userId});
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket!.onError((error) {
      print('Socket error: $error');
    });

    // Listen for new messages
    _socket!.on('message:new', (data) {
      print('New message received: $data');
      try {
        final message = MessageModel.fromJson(data);
        for (final listener in _messageListeners) {
          listener(message);
        }
      } catch (e) {
        print('Error parsing message: $e');
      }
    });

    // Listen for typing events
    _socket!.on('user:typing', (data) {
      final visitorId = data['userId'] as String?;
      final isTyping = data['isTyping'] as bool? ?? false;
      if (visitorId != null) {
        for (final listener in _typingListeners) {
          listener(visitorId, isTyping);
        }
      }
    });

    // Listen for presence events
    _socket!.on('user:presence', (data) {
      final visitorId = data['userId'] as String?;
      final isOnline = data['isOnline'] as bool? ?? false;
      if (visitorId != null) {
        for (final listener in _presenceListeners) {
          listener(visitorId, isOnline);
        }
      }
    });

    // Listen for call events
    _socket!.on('call:incoming', (data) {
      print('Incoming call: $data');
      for (final listener in _callListeners) {
        listener(data);
      }
    });

    _socket!.on('call:accepted', (data) {
      print('Call accepted: $data');
      for (final listener in _callListeners) {
        listener({...data, 'event': 'accepted'});
      }
    });

    _socket!.on('call:rejected', (data) {
      print('Call rejected: $data');
      for (final listener in _callListeners) {
        listener({...data, 'event': 'rejected'});
      }
    });

    _socket!.on('call:ended', (data) {
      print('Call ended: $data');
      for (final listener in _callListeners) {
        listener({...data, 'event': 'ended'});
      }
    });

    _socket!.on('call:signal', (data) {
      for (final listener in _callListeners) {
        listener({...data, 'event': 'signal'});
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.emit('user:offline', {'userId': _userId});
      _socket!.disconnect();
      _socket = null;
    }
    _messageListeners.clear();
    _typingListeners.clear();
    _presenceListeners.clear();
    _callListeners.clear();
  }

  // Message listeners
  void onNewMessage(Function(MessageModel) callback) {
    _messageListeners.add(callback);
  }

  void removeMessageListener(Function(MessageModel) callback) {
    _messageListeners.remove(callback);
  }

  // Typing listeners
  void onTyping(Function(String visitorId, bool isTyping) callback) {
    _typingListeners.add(callback);
  }

  void removeTypingListener(Function(String, bool) callback) {
    _typingListeners.remove(callback);
  }

  // Presence listeners
  void onPresence(Function(String visitorId, bool isOnline) callback) {
    _presenceListeners.add(callback);
  }

  void removePresenceListener(Function(String, bool) callback) {
    _presenceListeners.remove(callback);
  }

  // Call listeners
  void onCall(Function(Map<String, dynamic>) callback) {
    _callListeners.add(callback);
  }

  void removeCallListener(Function(Map<String, dynamic>) callback) {
    _callListeners.remove(callback);
  }

  // Emit events
  void sendTyping(String chatId, bool isTyping) {
    _socket?.emit('user:typing', {
      'chatId': chatId,
      'userId': _userId,
      'isTyping': isTyping,
    });
  }

  void joinChat(String chatId) {
    _socket?.emit('chat:join', {'chatId': chatId});
  }

  void leaveChat(String chatId) {
    _socket?.emit('chat:leave', {'chatId': chatId});
  }

  // Call events
  void initiateCall({
    required String recipientId,
    required String callType,
    required String callId,
  }) {
    _socket?.emit('call:initiate', {
      'callerId': _userId,
      'recipientId': recipientId,
      'callType': callType,
      'callId': callId,
    });
  }

  void acceptCall(String callId) {
    _socket?.emit('call:accept', {
      'callId': callId,
      'userId': _userId,
    });
  }

  void rejectCall(String callId) {
    _socket?.emit('call:reject', {
      'callId': callId,
      'userId': _userId,
    });
  }

  void endCall(String callId) {
    _socket?.emit('call:end', {
      'callId': callId,
      'userId': _userId,
    });
  }

  void sendSignal(String callId, String recipientId, Map<String, dynamic> signal) {
    _socket?.emit('call:signal', {
      'callId': callId,
      'senderId': _userId,
      'recipientId': recipientId,
      'signal': signal,
    });
  }

  bool get isConnected => _socket?.connected ?? false;
}
