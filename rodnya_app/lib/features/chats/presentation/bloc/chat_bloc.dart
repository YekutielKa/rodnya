import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/chat_model.dart';
import '../../data/datasources/chat_remote_datasource.dart';

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
  const SendTextMessage(this.content);
  @override
  List<Object?> get props => [content];
}

class SendMediaMessage extends ChatEvent {
  final String mediaUrl;
  final String type;
  final String? caption;
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final int? duration;
  const SendMediaMessage({
    required this.mediaUrl,
    required this.type,
    this.caption,
    this.thumbnailUrl,
    this.fileName,
    this.fileSize,
    this.duration,
  });
  @override
  List<Object?> get props => [mediaUrl, type];
}

class EditMessage extends ChatEvent {
  final String messageId;
  final String newContent;
  const EditMessage({required this.messageId, required this.newContent});
  @override
  List<Object?> get props => [messageId, newContent];
}

class DeleteMessage extends ChatEvent {
  final String messageId;
  const DeleteMessage(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

class ChatMessageReceived extends ChatEvent {
  final MessageModel message;
  const ChatMessageReceived(this.message);
  @override
  List<Object?> get props => [message];
}

class MessageStatusUpdated extends ChatEvent {
  final String messageId;
  final String status;
  const MessageStatusUpdated({required this.messageId, required this.status});
  @override
  List<Object?> get props => [messageId, status];
}

class SetReplyTo extends ChatEvent {
  final MessageModel message;
  const SetReplyTo(this.message);
  @override
  List<Object?> get props => [message];
}

class ClearReplyTo extends ChatEvent {
  const ClearReplyTo();
}

class UserTypingStarted extends ChatEvent {
  final String userId;
  final String userName;
  const UserTypingStarted({required this.userId, required this.userName});
  @override
  List<Object?> get props => [userId, userName];
}

class UserTypingStopped extends ChatEvent {
  final String userId;
  const UserTypingStopped(this.userId);
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
  final bool hasMore;
  final bool isLoadingMore;
  final bool isSending;
  final Map<String, String> typingUsers;
  final MessageModel? replyTo;
  final String? error;

  const ChatLoaded({
    required this.chat,
    required this.messages,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isSending = false,
    this.typingUsers = const {},
    this.replyTo,
    this.error,
  });

  ChatLoaded copyWith({
    ChatModel? chat,
    List<MessageModel>? messages,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isSending,
    Map<String, String>? typingUsers,
    MessageModel? replyTo,
    bool clearReplyTo = false,
    String? error,
  }) {
    return ChatLoaded(
      chat: chat ?? this.chat,
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      typingUsers: typingUsers ?? this.typingUsers,
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
      error: error,
    );
  }

  String? get typingText {
    if (typingUsers.isEmpty) return null;
    if (typingUsers.length == 1) {
      return '${typingUsers.values.first} печатает...';
    }
    return '${typingUsers.length} человека печатают...';
  }

  @override
  List<Object?> get props => [chat, messages, hasMore, isLoadingMore, isSending, typingUsers, replyTo, error];
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
  final ChatRemoteDatasource _remoteDatasource;
  
  String? _currentChatId;
  int _currentPage = 1;
  static const int _pageSize = 50;

  ChatBloc(this._remoteDatasource) : super(const ChatInitial()) {
    on<LoadChat>(_onLoadChat);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<SendTextMessage>(_onSendTextMessage);
    on<SendMediaMessage>(_onSendMediaMessage);
    on<EditMessage>(_onEditMessage);
    on<DeleteMessage>(_onDeleteMessage);
    on<ChatMessageReceived>(_onChatMessageReceived);
    on<MessageStatusUpdated>(_onMessageStatusUpdated);
    on<SetReplyTo>(_onSetReplyTo);
    on<ClearReplyTo>(_onClearReplyTo);
    on<UserTypingStarted>(_onUserTypingStarted);
    on<UserTypingStopped>(_onUserTypingStopped);
  }

  Future<void> _onLoadChat(LoadChat event, Emitter<ChatState> emit) async {
    _currentChatId = event.chatId;
    _currentPage = 1;
    emit(const ChatLoading());

    try {
      final chat = await _remoteDatasource.getChat(event.chatId);
      final messages = await _remoteDatasource.getMessages(
        chatId: event.chatId,
        limit: _pageSize,
        offset: 0,
      );

      emit(ChatLoaded(
        chat: chat,
        messages: messages,
        hasMore: messages.length >= _pageSize,
      ));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onLoadMoreMessages(LoadMoreMessages event, Emitter<ChatState> emit) async {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;
    
    if (currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      _currentPage++;
      final messages = await _remoteDatasource.getMessages(
        chatId: _currentChatId!,
        limit: _pageSize,
        offset: (_currentPage - 1) * _pageSize,
      );

      emit(currentState.copyWith(
        messages: [...currentState.messages, ...messages],
        hasMore: messages.length >= _pageSize,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false, error: e.toString()));
    }
  }

  Future<void> _onSendTextMessage(SendTextMessage event, Emitter<ChatState> emit) async {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;

    emit(currentState.copyWith(isSending: true));

    try {
      final sentMessage = await _remoteDatasource.sendMessage(
        chatId: _currentChatId!,
        type: 'text',
        content: event.content,
        replyToId: currentState.replyTo?.id,
      );

      emit(currentState.copyWith(
        messages: [sentMessage, ...currentState.messages],
        isSending: false,
        clearReplyTo: true,
      ));
    } catch (e) {
      emit(currentState.copyWith(isSending: false, error: e.toString()));
    }
  }

  Future<void> _onSendMediaMessage(SendMediaMessage event, Emitter<ChatState> emit) async {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;

    emit(currentState.copyWith(isSending: true));

    try {
      final sentMessage = await _remoteDatasource.sendMessage(
        chatId: _currentChatId!,
        type: event.type,
        content: event.caption,
        mediaUrl: event.mediaUrl,
        thumbnailUrl: event.thumbnailUrl,
        fileName: event.fileName,
        fileSize: event.fileSize,
        duration: event.duration,
        replyToId: currentState.replyTo?.id,
      );

      emit(currentState.copyWith(
        messages: [sentMessage, ...currentState.messages],
        isSending: false,
        clearReplyTo: true,
      ));
    } catch (e) {
      emit(currentState.copyWith(isSending: false, error: e.toString()));
    }
  }

  Future<void> _onEditMessage(EditMessage event, Emitter<ChatState> emit) async {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;

    try {
      await _remoteDatasource.editMessage(
        messageId: event.messageId,
        chatId: _currentChatId!,
        content: event.newContent,
      );

      final updatedMessages = currentState.messages.map((m) {
        if (m.id == event.messageId) {
          return m.copyWith(
            content: event.newContent,
            isEdited: true,
            editedAt: DateTime.now(),
          );
        }
        return m;
      }).toList();

      emit(currentState.copyWith(messages: updatedMessages));
    } catch (e) {
      emit(currentState.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleteMessage(DeleteMessage event, Emitter<ChatState> emit) async {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;

    try {
      await _remoteDatasource.deleteMessage(
        messageId: event.messageId,
        chatId: _currentChatId!,
      );

      final updatedMessages = currentState.messages.map((m) {
        if (m.id == event.messageId) {
          return m.copyWith(isDeleted: true);
        }
        return m;
      }).toList();

      emit(currentState.copyWith(messages: updatedMessages));
    } catch (e) {
      emit(currentState.copyWith(error: e.toString()));
    }
  }

  void _onChatMessageReceived(ChatMessageReceived event, Emitter<ChatState> emit) {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;

    // Only add if same chat and not duplicate
    if (event.message.chatId != _currentChatId) return;
    if (currentState.messages.any((m) => m.id == event.message.id)) return;

    emit(currentState.copyWith(
      messages: [event.message, ...currentState.messages],
    ));
  }

  void _onMessageStatusUpdated(MessageStatusUpdated event, Emitter<ChatState> emit) {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;

    final status = MessageStatus.values.firstWhere(
      (s) => s.name == event.status,
      orElse: () => MessageStatus.sent,
    );

    final updatedMessages = currentState.messages.map((m) {
      if (m.id == event.messageId) {
        return m.copyWith(status: status);
      }
      return m;
    }).toList();

    emit(currentState.copyWith(messages: updatedMessages));
  }

  void _onSetReplyTo(SetReplyTo event, Emitter<ChatState> emit) {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;
    emit(currentState.copyWith(replyTo: event.message));
  }

  void _onClearReplyTo(ClearReplyTo event, Emitter<ChatState> emit) {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;
    emit(currentState.copyWith(clearReplyTo: true));
  }

  void _onUserTypingStarted(UserTypingStarted event, Emitter<ChatState> emit) {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;

    final updatedTyping = Map<String, String>.from(currentState.typingUsers);
    updatedTyping[event.userId] = event.userName;

    emit(currentState.copyWith(typingUsers: updatedTyping));

    // Auto-remove after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      if (!isClosed) {
        add(UserTypingStopped(event.userId));
      }
    });
  }

  void _onUserTypingStopped(UserTypingStopped event, Emitter<ChatState> emit) {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;

    final updatedTyping = Map<String, String>.from(currentState.typingUsers);
    updatedTyping.remove(event.userId);

    emit(currentState.copyWith(typingUsers: updatedTyping));
  }
}
