import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/chat_model.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../../../core/api/socket_service.dart';

// EVENTS
abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class LoadMessages extends ChatEvent {
  final String chatId;
  final bool refresh;
  const LoadMessages({required this.chatId, this.refresh = false});
  @override
  List<Object?> get props => [chatId, refresh];
}

class LoadMoreMessages extends ChatEvent {
  const LoadMoreMessages();
}

class SendTextMessage extends ChatEvent {
  final String content;
  final MessageModel? replyTo;
  const SendTextMessage({required this.content, this.replyTo});
  @override
  List<Object?> get props => [content, replyTo];
}

class SendMediaMessage extends ChatEvent {
  final File file;
  final String type;
  final String? caption;
  final MessageModel? replyTo;
  const SendMediaMessage({required this.file, required this.type, this.caption, this.replyTo});
  @override
  List<Object?> get props => [file, type];
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
  const DeleteMessage({required this.messageId});
  @override
  List<Object?> get props => [messageId];
}

class ReceiveMessage extends ChatEvent {
  final MessageModel message;
  const ReceiveMessage(this.message);
  @override
  List<Object?> get props => [message];
}

class UpdateMessageStatus extends ChatEvent {
  final String messageId;
  final String status;
  const UpdateMessageStatus({required this.messageId, required this.status});
  @override
  List<Object?> get props => [messageId, status];
}

class StartTyping extends ChatEvent { const StartTyping(); }
class StopTyping extends ChatEvent { const StopTyping(); }

class UserStartedTyping extends ChatEvent {
  final String userId;
  final String userName;
  const UserStartedTyping({required this.userId, required this.userName});
  @override
  List<Object?> get props => [userId, userName];
}

class UserStoppedTyping extends ChatEvent {
  final String userId;
  const UserStoppedTyping({required this.userId});
  @override
  List<Object?> get props => [userId];
}

// STATES
abstract class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState { const ChatInitial(); }
class ChatLoading extends ChatState { const ChatLoading(); }

class ChatLoaded extends ChatState {
  final String chatId;
  final List<MessageModel> messages;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isSending;
  final Map<String, String> typingUsers;
  final String? error;

  const ChatLoaded({required this.chatId, required this.messages, this.hasMore = true,
    this.isLoadingMore = false, this.isSending = false, this.typingUsers = const {}, this.error});

  ChatLoaded copyWith({List<MessageModel>? messages, bool? hasMore, bool? isLoadingMore,
    bool? isSending, Map<String, String>? typingUsers, String? error}) {
    return ChatLoaded(chatId: chatId, messages: messages ?? this.messages, hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore, isSending: isSending ?? this.isSending,
      typingUsers: typingUsers ?? this.typingUsers, error: error);
  }

  String? get typingText {
    if (typingUsers.isEmpty) return null;
    if (typingUsers.length == 1) return '${typingUsers.values.first} печатает...';
    return '${typingUsers.length} человека печатают...';
  }

  @override
  List<Object?> get props => [chatId, messages, hasMore, isLoadingMore, isSending, typingUsers, error];
}

class ChatError extends ChatState {
  final String message;
  const ChatError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLOC
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRemoteDatasource _remoteDatasource;
  final SocketService _socketService;
  final String currentUserId;
  
  final _uuid = const Uuid();
  String? _currentChatId;
  int _currentPage = 0;
  static const int _pageSize = 50;
  Timer? _typingTimer;

  ChatBloc({required ChatRemoteDatasource remoteDatasource, required SocketService socketService, required this.currentUserId})
      : _remoteDatasource = remoteDatasource, _socketService = socketService, super(const ChatInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<SendTextMessage>(_onSendTextMessage);
    on<EditMessage>(_onEditMessage);
    on<DeleteMessage>(_onDeleteMessage);
    on<ReceiveMessage>(_onReceiveMessage);
    on<UpdateMessageStatus>(_onUpdateMessageStatus);
    on<StartTyping>(_onStartTyping);
    on<StopTyping>(_onStopTyping);
    on<UserStartedTyping>(_onUserStartedTyping);
    on<UserStoppedTyping>(_onUserStoppedTyping);
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _socketService.onNewMessage((message) {
      if (_currentChatId != null && message.chatId == _currentChatId) add(ReceiveMessage(message));
    });
    _socketService.onMessageStatus((messageId, status, userId) {
      add(UpdateMessageStatus(messageId: messageId, status: status));
    });
    _socketService.onTypingStart((chatId, userId, userName) {
      if (_currentChatId == chatId && userId != currentUserId) add(UserStartedTyping(userId: userId, userName: userName));
    });
    _socketService.onTypingStop((chatId, userId) {
      if (_currentChatId == chatId) add(UserStoppedTyping(userId: userId));
    });
  }

  Future<void> _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) async {
    _currentChatId = event.chatId;
    _currentPage = 0;
    if (!event.refresh) emit(const ChatLoading());
    try {
      final messages = await _remoteDatasource.getMessages(chatId: event.chatId, limit: _pageSize, offset: 0);
      emit(ChatLoaded(chatId: event.chatId, messages: messages, hasMore: messages.length >= _pageSize));
      if (messages.isNotEmpty && messages.first.senderId != currentUserId) {
        _socketService.sendRead(messages.first.id, event.chatId);
      }
    } catch (e) { emit(ChatError(e.toString())); }
  }

  Future<void> _onLoadMoreMessages(LoadMoreMessages event, Emitter<ChatState> emit) async {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;
    if (currentState.isLoadingMore || !currentState.hasMore) return;
    emit(currentState.copyWith(isLoadingMore: true));
    try {
      _currentPage++;
      final messages = await _remoteDatasource.getMessages(chatId: currentState.chatId, limit: _pageSize, offset: _currentPage * _pageSize);
      emit(currentState.copyWith(messages: [...currentState.messages, ...messages], hasMore: messages.length >= _pageSize, isLoadingMore: false));
    } catch (e) { emit(currentState.copyWith(isLoadingMore: false, error: e.toString())); }
  }

  Future<void> _onSendTextMessage(SendTextMessage event, Emitter<ChatState> emit) async {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;
    final optimisticMessage = MessageModel.optimistic(id: _uuid.v4(), chatId: currentState.chatId,
      senderId: currentUserId, type: MessageType.text, content: event.content, replyTo: event.replyTo);
    emit(currentState.copyWith(messages: [optimisticMessage, ...currentState.messages], isSending: true));
    try {
      final sentMessage = await _remoteDatasource.sendMessage(chatId: currentState.chatId, type: 'text',
        content: event.content, replyToId: event.replyTo?.id);
      final updatedMessages = currentState.messages.map((m) => m.id == optimisticMessage.id ? sentMessage : m).toList();
      emit(currentState.copyWith(messages: [sentMessage, ...updatedMessages.where((m) => m.id != optimisticMessage.id)], isSending: false));
    } catch (e) {
      final failedMessage = optimisticMessage.copyWith(status: MessageStatus.failed);
      final updatedMessages = currentState.messages.map((m) => m.id == optimisticMessage.id ? failedMessage : m).toList();
      emit(currentState.copyWith(messages: updatedMessages, isSending: false, error: e.toString()));
    }
  }

  Future<void> _onEditMessage(EditMessage event, Emitter<ChatState> emit) async {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;
    try {
      await _remoteDatasource.editMessage(messageId: event.messageId, chatId: currentState.chatId, content: event.newContent);
      final updatedMessages = currentState.messages.map((m) {
        if (m.id == event.messageId) return m.copyWith(content: event.newContent, isEdited: true, editedAt: DateTime.now());
        return m;
      }).toList();
      emit(currentState.copyWith(messages: updatedMessages));
    } catch (e) { emit(currentState.copyWith(error: e.toString())); }
  }

  Future<void> _onDeleteMessage(DeleteMessage event, Emitter<ChatState> emit) async {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;
    try {
      await _remoteDatasource.deleteMessage(messageId: event.messageId, chatId: currentState.chatId);
      final updatedMessages = currentState.messages.map((m) {
        if (m.id == event.messageId) return m.copyWith(isDeleted: true);
        return m;
      }).toList();
      emit(currentState.copyWith(messages: updatedMessages));
    } catch (e) { emit(currentState.copyWith(error: e.toString())); }
  }

  void _onReceiveMessage(ReceiveMessage event, Emitter<ChatState> emit) {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;
    if (currentState.messages.any((m) => m.id == event.message.id)) return;
    emit(currentState.copyWith(messages: [event.message, ...currentState.messages]));
    if (event.message.senderId != currentUserId) _socketService.sendRead(event.message.id, currentState.chatId);
  }

  void _onUpdateMessageStatus(UpdateMessageStatus event, Emitter<ChatState> emit) {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;
    final status = MessageStatus.values.firstWhere((s) => s.name == event.status, orElse: () => MessageStatus.sent);
    final updatedMessages = currentState.messages.map((m) {
      if (m.id == event.messageId) return m.copyWith(status: status);
      return m;
    }).toList();
    emit(currentState.copyWith(messages: updatedMessages));
  }

  void _onStartTyping(StartTyping event, Emitter<ChatState> emit) {
    if (_currentChatId == null) return;
    _socketService.sendTypingStart(_currentChatId!);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 5), () => add(const StopTyping()));
  }

  void _onStopTyping(StopTyping event, Emitter<ChatState> emit) {
    if (_currentChatId == null) return;
    _typingTimer?.cancel();
    _socketService.sendTypingStop(_currentChatId!);
  }

  void _onUserStartedTyping(UserStartedTyping event, Emitter<ChatState> emit) {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;
    final updatedTyping = Map<String, String>.from(currentState.typingUsers);
    updatedTyping[event.userId] = event.userName;
    emit(currentState.copyWith(typingUsers: updatedTyping));
    Future.delayed(const Duration(seconds: 6), () { if (!isClosed) add(UserStoppedTyping(userId: event.userId)); });
  }

  void _onUserStoppedTyping(UserStoppedTyping event, Emitter<ChatState> emit) {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;
    final updatedTyping = Map<String, String>.from(currentState.typingUsers);
    updatedTyping.remove(event.userId);
    emit(currentState.copyWith(typingUsers: updatedTyping));
  }

  @override
  Future<void> close() { _typingTimer?.cancel(); return super.close(); }
}
