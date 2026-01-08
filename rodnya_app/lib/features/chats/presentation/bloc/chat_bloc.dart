import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/chat_model.dart';
import '../../data/datasources/chat_remote_datasource.dart';

// Events
abstract class ChatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadChat extends ChatEvent {
  final String chatId;
  LoadChat(this.chatId);
  
  @override
  List<Object?> get props => [chatId];
}

class LoadMessages extends ChatEvent {
  final String chatId;
  LoadMessages(this.chatId);
  
  @override
  List<Object?> get props => [chatId];
}

class LoadMoreMessages extends ChatEvent {}

class SendMessage extends ChatEvent {
  final String content;
  final String type;
  final String? mediaUrl;
  final String? replyToId;
  
  SendMessage({
    required this.content,
    this.type = 'text',
    this.mediaUrl,
    this.replyToId,
  });
  
  @override
  List<Object?> get props => [content, type, mediaUrl, replyToId];
}

class MessageReceivedInChat extends ChatEvent {
  final MessageModel message;
  MessageReceivedInChat(this.message);
  
  @override
  List<Object?> get props => [message];
}

class DeleteMessage extends ChatEvent {
  final String messageId;
  DeleteMessage(this.messageId);
  
  @override
  List<Object?> get props => [messageId];
}

class MarkChatAsRead extends ChatEvent {}

class SetReplyTo extends ChatEvent {
  final MessageModel? message;
  SetReplyTo(this.message);
  
  @override
  List<Object?> get props => [message];
}

// States
abstract class ChatState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final ChatModel chat;
  final List<MessageModel> messages;
  final bool hasMoreMessages;
  final bool isSending;
  final MessageModel? replyTo;

  ChatLoaded({
    required this.chat,
    required this.messages,
    this.hasMoreMessages = true,
    this.isSending = false,
    this.replyTo,
  });

  @override
  List<Object?> get props => [chat, messages, hasMoreMessages, isSending, replyTo];

  ChatLoaded copyWith({
    ChatModel? chat,
    List<MessageModel>? messages,
    bool? hasMoreMessages,
    bool? isSending,
    MessageModel? replyTo,
    bool clearReplyTo = false,
  }) {
    return ChatLoaded(
      chat: chat ?? this.chat,
      messages: messages ?? this.messages,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isSending: isSending ?? this.isSending,
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
    );
  }
}

class ChatError extends ChatState {
  final String message;
  ChatError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRemoteDatasource _remoteDatasource;
  String? _currentChatId;

  ChatBloc(this._remoteDatasource) : super(ChatInitial()) {
    on<LoadChat>(_onLoadChat);
    on<LoadMessages>(_onLoadMessages);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<SendMessage>(_onSendMessage);
    on<MessageReceivedInChat>(_onMessageReceived);
    on<DeleteMessage>(_onDeleteMessage);
    on<MarkChatAsRead>(_onMarkAsRead);
    on<SetReplyTo>(_onSetReplyTo);
  }

  Future<void> _onLoadChat(LoadChat event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    _currentChatId = event.chatId;
    try {
      final chat = await _remoteDatasource.getChat(event.chatId);
      final messages = await _remoteDatasource.getMessages(event.chatId);
      
      emit(ChatLoaded(
        chat: chat,
        messages: messages,
        hasMoreMessages: messages.length >= 50,
      ));
      
      // Mark as read
      _remoteDatasource.markAsRead(event.chatId);
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) async {
    _currentChatId = event.chatId;
    try {
      final messages = await _remoteDatasource.getMessages(event.chatId);
      final currentState = state;
      
      if (currentState is ChatLoaded) {
        emit(currentState.copyWith(
          messages: messages,
          hasMoreMessages: messages.length >= 50,
        ));
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _onLoadMoreMessages(LoadMoreMessages event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is ChatLoaded && 
        currentState.hasMoreMessages && 
        currentState.messages.isNotEmpty &&
        _currentChatId != null) {
      try {
        final oldestMessage = currentState.messages.last;
        final moreMessages = await _remoteDatasource.getMessages(
          _currentChatId!,
          before: oldestMessage.id,
        );
        
        emit(currentState.copyWith(
          messages: [...currentState.messages, ...moreMessages],
          hasMoreMessages: moreMessages.length >= 50,
        ));
      } catch (e) {
        // Keep current state on error
      }
    }
  }

  Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is ChatLoaded && _currentChatId != null) {
      emit(currentState.copyWith(isSending: true));
      
      try {
        final message = await _remoteDatasource.sendMessage(
          chatId: _currentChatId!,
          type: event.type,
          content: event.content,
          mediaUrl: event.mediaUrl,
          replyToId: currentState.replyTo?.id ?? event.replyToId,
        );
        
        emit(currentState.copyWith(
          messages: [message, ...currentState.messages],
          isSending: false,
          clearReplyTo: true,
        ));
      } catch (e) {
        emit(currentState.copyWith(isSending: false));
      }
    }
  }

  void _onMessageReceived(MessageReceivedInChat event, Emitter<ChatState> emit) {
    final currentState = state;
    if (currentState is ChatLoaded && event.message.chatId == _currentChatId) {
      // Check if message already exists
      final exists = currentState.messages.any((m) => m.id == event.message.id);
      if (!exists) {
        emit(currentState.copyWith(
          messages: [event.message, ...currentState.messages],
        ));
        // Mark as read since user is viewing chat
        if (_currentChatId != null) {
          _remoteDatasource.markAsRead(_currentChatId!);
        }
      }
    }
  }

  Future<void> _onDeleteMessage(DeleteMessage event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is ChatLoaded && _currentChatId != null) {
      try {
        await _remoteDatasource.deleteMessage(_currentChatId!, event.messageId);
        
        final updatedMessages = currentState.messages
            .where((m) => m.id != event.messageId)
            .toList();
        
        emit(currentState.copyWith(messages: updatedMessages));
      } catch (e) {
        // Handle error
      }
    }
  }

  Future<void> _onMarkAsRead(MarkChatAsRead event, Emitter<ChatState> emit) async {
    if (_currentChatId != null) {
      await _remoteDatasource.markAsRead(_currentChatId!);
    }
  }

  void _onSetReplyTo(SetReplyTo event, Emitter<ChatState> emit) {
    final currentState = state;
    if (currentState is ChatLoaded) {
      if (event.message == null) {
        emit(currentState.copyWith(clearReplyTo: true));
      } else {
        emit(currentState.copyWith(replyTo: event.message));
      }
    }
  }
}
