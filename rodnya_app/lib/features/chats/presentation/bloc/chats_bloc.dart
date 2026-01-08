import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/chat_model.dart';
import '../../data/datasources/chat_remote_datasource.dart';

// Events
abstract class ChatsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadChats extends ChatsEvent {}

class RefreshChats extends ChatsEvent {}

class LoadMoreChats extends ChatsEvent {}

class ChatReceived extends ChatsEvent {
  final ChatModel chat;
  ChatReceived(this.chat);
  
  @override
  List<Object?> get props => [chat];
}

class MessageReceived extends ChatsEvent {
  final MessageModel message;
  MessageReceived(this.message);
  
  @override
  List<Object?> get props => [message];
}

class CreateDirectChat extends ChatsEvent {
  final String userId;
  CreateDirectChat(this.userId);
  
  @override
  List<Object?> get props => [userId];
}

class CreateGroupChat extends ChatsEvent {
  final String name;
  final List<String> participantIds;
  CreateGroupChat({required this.name, required this.participantIds});
  
  @override
  List<Object?> get props => [name, participantIds];
}

// States
abstract class ChatsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ChatsInitial extends ChatsState {}

class ChatsLoading extends ChatsState {}

class ChatsLoaded extends ChatsState {
  final List<ChatModel> chats;
  final bool hasMore;
  final int currentPage;

  ChatsLoaded({
    required this.chats,
    this.hasMore = true,
    this.currentPage = 1,
  });

  @override
  List<Object?> get props => [chats, hasMore, currentPage];

  ChatsLoaded copyWith({
    List<ChatModel>? chats,
    bool? hasMore,
    int? currentPage,
  }) {
    return ChatsLoaded(
      chats: chats ?? this.chats,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class ChatsError extends ChatsState {
  final String message;
  ChatsError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class ChatsBloc extends Bloc<ChatsEvent, ChatsState> {
  final ChatRemoteDatasource _remoteDatasource;

  ChatsBloc(this._remoteDatasource) : super(ChatsInitial()) {
    on<LoadChats>(_onLoadChats);
    on<RefreshChats>(_onRefreshChats);
    on<LoadMoreChats>(_onLoadMoreChats);
    on<ChatReceived>(_onChatReceived);
    on<MessageReceived>(_onMessageReceived);
    on<CreateDirectChat>(_onCreateDirectChat);
    on<CreateGroupChat>(_onCreateGroupChat);
  }

  Future<void> _onLoadChats(LoadChats event, Emitter<ChatsState> emit) async {
    emit(ChatsLoading());
    try {
      final chats = await _remoteDatasource.getChats(page: 1);
      emit(ChatsLoaded(
        chats: chats,
        hasMore: chats.length >= 20,
        currentPage: 1,
      ));
    } catch (e) {
      emit(ChatsError(e.toString()));
    }
  }

  Future<void> _onRefreshChats(RefreshChats event, Emitter<ChatsState> emit) async {
    try {
      final chats = await _remoteDatasource.getChats(page: 1);
      emit(ChatsLoaded(
        chats: chats,
        hasMore: chats.length >= 20,
        currentPage: 1,
      ));
    } catch (e) {
      emit(ChatsError(e.toString()));
    }
  }

  Future<void> _onLoadMoreChats(LoadMoreChats event, Emitter<ChatsState> emit) async {
    final currentState = state;
    if (currentState is ChatsLoaded && currentState.hasMore) {
      try {
        final nextPage = currentState.currentPage + 1;
        final newChats = await _remoteDatasource.getChats(page: nextPage);
        emit(currentState.copyWith(
          chats: [...currentState.chats, ...newChats],
          hasMore: newChats.length >= 20,
          currentPage: nextPage,
        ));
      } catch (e) {
        // Keep current state on error
      }
    }
  }

  void _onChatReceived(ChatReceived event, Emitter<ChatsState> emit) {
    final currentState = state;
    if (currentState is ChatsLoaded) {
      final updatedChats = List<ChatModel>.from(currentState.chats);
      final index = updatedChats.indexWhere((c) => c.id == event.chat.id);
      if (index >= 0) {
        updatedChats[index] = event.chat;
      } else {
        updatedChats.insert(0, event.chat);
      }
      // Sort by updatedAt
      updatedChats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      emit(currentState.copyWith(chats: updatedChats));
    }
  }

  void _onMessageReceived(MessageReceived event, Emitter<ChatsState> emit) {
    final currentState = state;
    if (currentState is ChatsLoaded) {
      final updatedChats = currentState.chats.map((chat) {
        if (chat.id == event.message.chatId) {
          return ChatModel(
            id: chat.id,
            type: chat.type,
            name: chat.name,
            avatarUrl: chat.avatarUrl,
            participants: chat.participants,
            lastMessage: event.message,
            unreadCount: chat.unreadCount + 1,
            createdAt: chat.createdAt,
            updatedAt: DateTime.now(),
          );
        }
        return chat;
      }).toList();
      // Sort by updatedAt
      updatedChats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      emit(currentState.copyWith(chats: updatedChats));
    }
  }

  Future<void> _onCreateDirectChat(CreateDirectChat event, Emitter<ChatsState> emit) async {
    try {
      final chat = await _remoteDatasource.createDirectChat(event.userId);
      add(ChatReceived(chat));
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _onCreateGroupChat(CreateGroupChat event, Emitter<ChatsState> emit) async {
    try {
      final chat = await _remoteDatasource.createGroupChat(
        name: event.name,
        participantIds: event.participantIds,
      );
      add(ChatReceived(chat));
    } catch (e) {
      // Handle error
    }
  }
}
