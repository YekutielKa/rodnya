import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../bloc/chats_bloc.dart';
import '../../data/models/chat_model.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<ChatsBloc>().add(LoadChats());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ChatsBloc>().add(LoadMoreChats());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: BlocBuilder<ChatsBloc, ChatsState>(
        builder: (context, state) {
          if (state is ChatsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ChatsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ошибка загрузки',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ChatsBloc>().add(LoadChats());
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          if (state is ChatsLoaded) {
            if (state.chats.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Нет чатов',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Начните общение с близкими',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<ChatsBloc>().add(RefreshChats());
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount: state.chats.length,
                itemBuilder: (context, index) {
                  final chat = state.chats[index];
                  return ChatListItem(
                    chat: chat,
                    onTap: () {
                      context.push('/chat/${chat.id}');
                    },
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewChatDialog(context);
        },
        child: const Icon(Icons.edit),
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Новый чат'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/contacts');
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text('Создать группу'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to create group
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class ChatListItem extends StatelessWidget {
  final ChatModel chat;
  final VoidCallback onTap;
  // TODO: Get current user ID from auth
  final String currentUserId = '';

  const ChatListItem({
    super.key,
    required this.chat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = chat.getDisplayName(currentUserId);
    final avatarUrl = chat.getDisplayAvatar(currentUserId);

    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null
            ? Text(
                _getInitials(displayName),
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.lastMessage != null)
            Text(
              _formatTime(chat.lastMessage!.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: chat.unreadCount > 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              chat.lastMessage?.getPreviewText() ?? 'Нет сообщений',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: chat.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat.Hm().format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Вчера';
    } else if (now.difference(dateTime).inDays < 7) {
      return DateFormat.E('ru').format(dateTime);
    } else {
      return DateFormat.MMMd('ru').format(dateTime);
    }
  }
}
