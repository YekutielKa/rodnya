import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/models/chat_model.dart';

// ============================================================================
// EVENTS
// ============================================================================

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class LoadChat extends ChatEvent {
  final String chatId;
  const LoadChat(this.chatId);
  @override
  List<Object?> get props => [chatId];
}

class LoadMoreMessages extends ChatEvent {
  const LoadMoreMessages();
}

class SendTextMessage extends ChatEvent {
  final String content;
  final String? replyToId;
  const SendTextMessage(this.content, {this.replyToId});
  @override
  List<Object?> get props => [content, replyToId];
}

class SendMediaMessage extends ChatEvent {
  final MessageType type;
  final String mediaUrl;
  final String? content;
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final int? duration;
  final String? replyToId;
  
  const SendMediaMessage({
    required this.type,
    required this.mediaUrl,
    this.content,
    this.thumbnailUrl,
    this.fileName,
    this.fileSize,
    this.duration,
    this.replyToId,
  });
  
  @override
  List<Object?> get props => [type, mediaUrl, content, replyToId];
}

class SendVoiceMessage extends ChatEvent {
  final String audioUrl;
  final int duration;
  final String? replyToId;
  
  const SendVoiceMessage({
    required this.audioUrl,
    required this.duration,
    this.replyToId,
  });
  
  @override
  List<Object?> get props => [audioUrl, duration, replyToId];
}

class MessageReceived extends ChatEvent {
  final MessageModel message;
  const MessageReceived(this.message);
  @override
  List<Object?> get props => [message];
}

class MessageUpdated extends ChatEvent {
  final MessageModel message;
  const MessageUpdated(this.message);
  @override
  List<Object?> get props => [message];
}

class MessageDeleted extends ChatEvent {
  final String messageId;
  const MessageDeleted(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

class DeleteMessage extends ChatEvent {
  final String messageId;
  const DeleteMessage(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

class EditMessage extends ChatEvent {
  final String messageId;
  final String newContent;
  const EditMessage(this.messageId, this.newContent);
  @override
  List<Object?> get props => [messageId, newContent];
}

class SetReplyTo extends ChatEvent {
  final MessageModel? message;
  const SetReplyTo(this.message);
  @override
  List<Object?> get props => [message];
}

class ClearReplyTo extends ChatEvent {
  const ClearReplyTo();
}

class MarkAsRead extends ChatEvent {
  const MarkAsRead();
}

class UserTyping extends ChatEvent {
  final String userId;
  final String userName;
  const UserTyping(this.userId, this.userName);
  @override
  List<Object?> get props => [userId, userName];
}

class UserStoppedTyping extends ChatEvent {
  final String userId;
  const UserStoppedTyping(this.userId);
  @override
  List<Object?> get props => [userId];
}

// ============================================================================
// STATES
// ============================================================================

abstract class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatLoaded extends ChatState {
  final ChatModel chat;
  final List<MessageModel> messages;
  final bool hasMoreMessages;
  final bool isLoadingMore;
  final bool isSending;
  final MessageModel? replyTo;
  final Map<String, String> typingUsers; // userId -> userName
  final String? error;

  const ChatLoaded({
    required this.chat,
    required this.messages,
    this.hasMoreMessages = true,
    this.isLoadingMore = false,
    this.isSending = false,
    this.replyTo,
    this.typingUsers = const {},
    this.error,
  });

  ChatLoaded copyWith({
    ChatModel? chat,
    List<MessageModel>? messages,
    bool? hasMoreMessages,
    bool? isLoadingMore,
    bool? isSending,
    MessageModel? replyTo,
    bool clearReplyTo = false,
    Map<String, String>? typingUsers,
    String? error,
    bool clearError = false,
  }) {
    return ChatLoaded(
      chat: chat ?? this.chat,
      messages: messages ?? this.messages,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
      typingUsers: typingUsers ?? this.typingUsers,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    chat, messages, hasMoreMessages, isLoadingMore, 
    isSending, replyTo, typingUsers, error
  ];
}

class ChatError extends ChatState {
  final String message;
  const ChatError(this.message);
  @override
  List<Object?> get props => [message];
}

// ============================================================================
// BLOC
// ============================================================================

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRemoteDatasource _datasource;
  final String _currentUserId;
  final String? _currentUserName;
  
  String? _currentChatId;
  final _uuid = const Uuid();
  
  // For typing indicator debounce
  Timer? _typingTimer;
  
  ChatBloc({
    required ChatRemoteDatasource datasource,
    required String currentUserId,
    String? currentUserName,
  }) : _datasource = datasource,
       _currentUserId = currentUserId,
       _currentUserName = currentUserName,
       super(const ChatInitial()) {
    on<LoadChat>(_onLoadChat);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<SendTextMessage>(_onSendTextMessage);
    on<SendMediaMessage>(_onSendMediaMessage);
    on<SendVoiceMessage>(_onSendVoiceMessage);
    on<MessageReceived>(_onMessageReceived);
    on<MessageUpdated>(_onMessageUpdated);
    on<MessageDeleted>(_onMessageDeleted);
    on<DeleteMessage>(_onDeleteMessage);
    on<EditMessage>(_onEditMessage);
    on<SetReplyTo>(_onSetReplyTo);
    on<ClearReplyTo>(_onClearReplyTo);
    on<MarkAsRead>(_onMarkAsRead);
    on<UserTyping>(_onUserTyping);
    on<UserStoppedTyping>(_onUserStoppedTyping);
  }

  String? get currentChatId => _currentChatId;

  Future<void> _onLoadChat(LoadChat event, Emitter<ChatState> emit) async {
    emit(const ChatLoading());
    _currentChatId = event.chatId;
    
    try {
      final chat = await _datasource.getChat(event.chatId);
      final messages = await _datasource.getMessages(event.chatId);
      
      emit(ChatLoaded(
        chat: chat,
        messages: messages,
        hasMoreMessages: messages.length >= 50,
      ));
      
      // Mark as read
      _datasource.markAsRead(event.chatId);
    } catch (e) {
      emit(ChatError('Не удалось загрузить чат: $e'));
    }
  }

  Future<void> _onLoadMoreMessages(LoadMoreMessages event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is! ChatLoaded || 
        currentState.isLoadingMore || 
        !currentState.hasMoreMessages ||
        _currentChatId == null) {
      return;
    }

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      // Get oldest message date for pagination
      final oldestMessage = currentState.messages.isNotEmpty 
          ? currentState.messages.last 
          : null;
      
      final moreMessages = await _datasource.getMessages(
        _currentChatId!,
        before: oldestMessage?.createdAt.toIso8601String(),
      );

      emit(currentState.copyWith(
        messages: [...currentState.messages, ...moreMessages],
        hasMoreMessages: moreMessages.length >= 50,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(
        isLoadingMore: false,
        error: 'Не удалось загрузить сообщения',
      ));
    }
  }

  Future<void> _onSendTextMessage(SendTextMessage event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is! ChatLoaded || _currentChatId == null) return;

    // Create optimistic message
    final tempId = 'temp_${_uuid.v4()}';
    final optimisticMessage = MessageModel.optimistic(
      tempId: tempId,
      chatId: _currentChatId!,
      senderId: _currentUserId,
      senderName: _currentUserName,
      content: event.content,
      replyTo: currentState.replyTo,
    );

    // Add optimistic message to UI immediately
    emit(currentState.copyWith(
      messages: [optimisticMessage, ...currentState.messages],
      isSending: true,
      clearReplyTo: true,
    ));

    try {
      final sentMessage = await _datasource.sendMessage(
        chatId: _currentChatId!,
        content: event.content,
        replyToId: currentState.replyTo?.id ?? event.replyToId,
      );

      // Replace optimistic message with real one
      final currentMessages = (state as ChatLoaded).messages;
      final updatedMessages = currentMessages.map((m) {
        return m.id == tempId ? sentMessage : m;
      }).toList();

      emit((state as ChatLoaded).copyWith(
        messages: updatedMessages,
        isSending: false,
      ));
    } catch (e) {
      // Mark optimistic message as failed
      final currentMessages = (state as ChatLoaded).messages;
      final updatedMessages = currentMessages.map((m) {
        return m.id == tempId 
            ? m.copyWith(status: MessageStatus.failed)
            : m;
      }).toList();

      emit((state as ChatLoaded).copyWith(
        messages: updatedMessages,
        isSending: false,
        error: 'Не удалось отправить сообщение',
      ));
    }
  }

  Future<void> _onSendMediaMessage(SendMediaMessage event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is! ChatLoaded || _currentChatId == null) return;

    final tempId = 'temp_${_uuid.v4()}';
    final optimisticMessage = MessageModel.optimistic(
      tempId: tempId,
      chatId: _currentChatId!,
      senderId: _currentUserId,
      senderName: _currentUserName,
      type: event.type,
      content: event.content,
      mediaUrl: event.mediaUrl,
      replyTo: currentState.replyTo,
    );

    emit(currentState.copyWith(
      messages: [optimisticMessage, ...currentState.messages],
      isSending: true,
      clearReplyTo: true,
    ));

    try {
      final sentMessage = await _datasource.sendMediaMessage(
        chatId: _currentChatId!,
        type: event.type,
        mediaUrl: event.mediaUrl,
        content: event.content,
        thumbnailUrl: event.thumbnailUrl,
        fileName: event.fileName,
        fileSize: event.fileSize,
        duration: event.duration,
        replyToId: currentState.replyTo?.id ?? event.replyToId,
      );

      final currentMessages = (state as ChatLoaded).messages;
      final updatedMessages = currentMessages.map((m) {
        return m.id == tempId ? sentMessage : m;
      }).toList();

      emit((state as ChatLoaded).copyWith(
        messages: updatedMessages,
        isSending: false,
      ));
    } catch (e) {
      final currentMessages = (state as ChatLoaded).messages;
      final updatedMessages = currentMessages.map((m) {
        return m.id == tempId 
            ? m.copyWith(status: MessageStatus.failed)
            : m;
      }).toList();

      emit((state as ChatLoaded).copyWith(
        messages: updatedMessages,
        isSending: false,
        error: 'Не удалось отправить медиа',
      ));
    }
  }

  Future<void> _onSendVoiceMessage(SendVoiceMessage event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is! ChatLoaded || _currentChatId == null) return;

    final tempId = 'temp_${_uuid.v4()}';
    final optimisticMessage = MessageModel(
      id: tempId,
      chatId: _currentChatId!,
      senderId: _currentUserId,
      senderName: _currentUserName,
      type: MessageType.voice,
      mediaUrl: event.audioUrl,
      duration: event.duration,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      replyTo: currentState.replyTo,
    );

    emit(currentState.copyWith(
      messages: [optimisticMessage, ...currentState.messages],
      isSending: true,
      clearReplyTo: true,
    ));

    try {
      final sentMessage = await _datasource.sendVoiceMessage(
        chatId: _currentChatId!,
        audioUrl: event.audioUrl,
        duration: event.duration,
        replyToId: currentState.replyTo?.id ?? event.replyToId,
      );

      final currentMessages = (state as ChatLoaded).messages;
      final updatedMessages = currentMessages.map((m) {
        return m.id == tempId ? sentMessage : m;
      }).toList();

      emit((state as ChatLoaded).copyWith(
        messages: updatedMessages,
        isSending: false,
      ));
    } catch (e) {
      final currentMessages = (state as ChatLoaded).messages;
      final updatedMessages = currentMessages.map((m) {
        return m.id == tempId 
            ? m.copyWith(status: MessageStatus.failed)
            : m;
      }).toList();

      emit((state as ChatLoaded).copyWith(
        messages: updatedMessages,
        isSending: false,
        error: 'Не удалось отправить голосовое сообщение',
      ));
    }
  }

  void _onMessageReceived(MessageReceived event, Emitter<ChatState> emit) {
    final currentState = state;
    if (currentState is! ChatLoaded) return;
    
    // Check if this message belongs to current chat
    if (event.message.chatId != _currentChatId) return;
    
    // Check if message already exists
    final exists = currentState.messages.any((m) => m.id == event.message.id);
    if (exists) return;

    emit(currentState.copyWith(
      messages: [event.message, ...currentState.messages],
    ));

    // Mark as read if user is in chat
    if (_currentChatId != null) {
      _datasource.markAsRead(_currentChatId!);
    }
  }

  void _onMessageUpdated(MessageUpdated event, Emitter<ChatState> emit) {
    final currentState = state;
    if (currentState is! ChatLoaded) return;

    final updatedMessages = currentState.messages.map((m) {
      return m.id == event.message.id ? event.message : m;
    }).toList();

    emit(currentState.copyWith(messages: updatedMessages));
  }

  void _onMessageDeleted(MessageDeleted event, Emitter<ChatState> emit) {
    final currentState = state;
    if (currentState is! ChatLoaded) return;

    final updatedMessages = currentState.messages.map((m) {
      return m.id == event.messageId 
          ? m.copyWith(isDeleted: true, content: 'Сообщение удалено')
          : m;
    }).toList();

    emit(currentState.copyWith(messages: updatedMessages));
  }

  Future<void> _onDeleteMessage(DeleteMessage event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is! ChatLoaded || _currentChatId == null) return;

    try {
      await _datasource.deleteMessage(_currentChatId!, event.messageId);
      
      final updatedMessages = currentState.messages.map((m) {
        return m.id == event.messageId 
            ? m.copyWith(isDeleted: true, content: 'Сообщение удалено')
            : m;
      }).toList();

      emit(currentState.copyWith(messages: updatedMessages));
    } catch (e) {
      emit(currentState.copyWith(error: 'Не удалось удалить сообщение'));
    }
  }

  Future<void> _onEditMessage(EditMessage event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is! ChatLoaded) return;

    try {
      final editedMessage = await _datasource.editMessage(
        event.messageId, 
        event.newContent,
      );

      final updatedMessages = currentState.messages.map((m) {
        return m.id == event.messageId ? editedMessage : m;
      }).toList();

      emit(currentState.copyWith(messages: updatedMessages));
    } catch (e) {
      emit(currentState.copyWith(error: 'Не удалось редактировать сообщение'));
    }
  }

  void _onSetReplyTo(SetReplyTo event, Emitter<ChatState> emit) {
    final currentState = state;
    if (currentState is ChatLoaded) {
      emit(currentState.copyWith(replyTo: event.message));
    }
  }

  void _onClearReplyTo(ClearReplyTo event, Emitter<ChatState> emit) {
    final currentState = state;
    if (currentState is ChatLoaded) {
      emit(currentState.copyWith(clearReplyTo: true));
    }
  }

  Future<void> _onMarkAsRead(MarkAsRead event, Emitter<ChatState> emit) async {
    if (_currentChatId != null) {
      await _datasource.markAsRead(_currentChatId!);
    }
  }

  void _onUserTyping(UserTyping event, Emitter<ChatState> emit) {
    final currentState = state;
    if (currentState is! ChatLoaded) return;
    
    // Don't show own typing
    if (event.userId == _currentUserId) return;

    final newTypingUsers = Map<String, String>.from(currentState.typingUsers);
    newTypingUsers[event.userId] = event.userName;

    emit(currentState.copyWith(typingUsers: newTypingUsers));

    // Auto-remove after 3 seconds
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      add(UserStoppedTyping(event.userId));
    });
  }

  void _onUserStoppedTyping(UserStoppedTyping event, Emitter<ChatState> emit) {
    final currentState = state;
    if (currentState is! ChatLoaded) return;

    final newTypingUsers = Map<String, String>.from(currentState.typingUsers);
    newTypingUsers.remove(event.userId);

    emit(currentState.copyWith(typingUsers: newTypingUsers));
  }

  @override
  Future<void> close() {
    _typingTimer?.cancel();
    return super.close();
  }
}
