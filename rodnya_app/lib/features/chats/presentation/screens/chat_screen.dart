import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/chat_bloc.dart';
import '../../data/models/chat_model.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadChat(widget.chatId));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ChatBloc>().add(LoadMoreMessages());
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      context.read<ChatBloc>().add(SendMessage(content: text));
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        String title = 'Чат';
        String? subtitle;

        if (state is ChatLoaded) {
          title = state.chat.getDisplayName(''); // TODO: pass currentUserId
          if (state.chat.type == 'direct') {
            final otherUser = state.chat.participants.firstWhere(
              (p) => p.userId != '', // TODO: compare with currentUserId
              orElse: () => ChatParticipant(userId: '', name: 'Неизвестный', isOnline: false),
            );
            subtitle = otherUser.isOnline ? 'в сети' : null;
          } else {
            subtitle = '${state.chat.participants.length} участников';
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: subtitle == 'в сети'
                              ? Colors.green
                              : Theme.of(context).colorScheme.outline,
                        ),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.videocam),
                onPressed: () {
                  // TODO: Start video call
                },
              ),
              IconButton(
                icon: const Icon(Icons.call),
                onPressed: () {
                  // TODO: Start audio call
                },
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'search',
                    child: Text('Поиск'),
                  ),
                  const PopupMenuItem(
                    value: 'media',
                    child: Text('Медиа'),
                  ),
                  const PopupMenuItem(
                    value: 'mute',
                    child: Text('Отключить уведомления'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _buildMessagesList(state),
              ),
              if (state is ChatLoaded && state.replyTo != null)
                _buildReplyPreview(context, state.replyTo!),
              _buildMessageInput(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessagesList(ChatState state) {
    if (state is ChatLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ChatError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ошибка: ${state.message}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<ChatBloc>().add(LoadChat(widget.chatId));
              },
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (state is ChatLoaded) {
      if (state.messages.isEmpty) {
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
                'Нет сообщений',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Напишите первое сообщение',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        itemCount: state.messages.length,
        itemBuilder: (context, index) {
          final message = state.messages[index];
          final isMe = message.senderId == ''; // TODO: compare with currentUserId
          final showDate = index == state.messages.length - 1 ||
              !_isSameDay(
                message.createdAt,
                state.messages[index + 1].createdAt,
              );

          return Column(
            children: [
              if (showDate) _buildDateDivider(message.createdAt),
              MessageBubble(
                message: message,
                isMe: isMe,
                onLongPress: () => _showMessageOptions(context, message),
                onReply: () {
                  context.read<ChatBloc>().add(SetReplyTo(message));
                  _focusNode.requestFocus();
                },
              ),
            ],
          );
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(date),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context, MessageModel replyTo) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  replyTo.senderName ?? 'Пользователь',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  replyTo.getPreviewText(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              context.read<ChatBloc>().add(SetReplyTo(null));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context, ChatState state) {
    final isSending = state is ChatLoaded && state.isSending;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {
              _showAttachmentOptions(context);
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Сообщение...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          isSending
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    Icons.send,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _sendMessage,
                ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, MessageModel message) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Ответить'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<ChatBloc>().add(SetReplyTo(message));
                  _focusNode.requestFocus();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Копировать'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Copy to clipboard
                },
              ),
              if (message.senderId == '') // TODO: compare with currentUserId
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<ChatBloc>().add(DeleteMessage(message.id));
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Фото'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Pick image
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Видео'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Pick video
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('Файл'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Pick file
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Сегодня';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Вчера';
    } else {
      return DateFormat.yMMMd('ru').format(date);
    }
  }
}

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback onLongPress;
  final VoidCallback onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onLongPress,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsets.only(
            left: isMe ? 48 : 0,
            right: isMe ? 0 : 48,
            bottom: 4,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe && message.senderName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.senderName!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (message.replyTo != null) _buildReplyPreview(context),
              _buildContent(context),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.Hm().format(message.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isMe
                          ? theme.colorScheme.onPrimary.withOpacity(0.7)
                          : theme.colorScheme.outline,
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.readBy.isNotEmpty ? Icons.done_all : Icons.done,
                      size: 14,
                      color: message.readBy.isNotEmpty
                          ? Colors.lightBlueAccent
                          : theme.colorScheme.onPrimary.withOpacity(0.7),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe
            ? theme.colorScheme.onPrimary.withOpacity(0.1)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.replyTo!.senderName ?? 'Пользователь',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            message.replyTo!.getPreviewText(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isMe ? theme.colorScheme.onPrimary : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    if (message.isDeleted) {
      return Text(
        'Сообщение удалено',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: isMe
              ? theme.colorScheme.onPrimary.withOpacity(0.7)
              : theme.colorScheme.outline,
        ),
      );
    }

    switch (message.type) {
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: message.mediaUrl != null
              ? Image.network(
                  message.mediaUrl!,
                  width: 200,
                  fit: BoxFit.cover,
                )
              : const Icon(Icons.image, size: 100),
        );
      case 'video':
        return Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white),
          ),
        );
      case 'audio':
      case 'voice':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow),
            const SizedBox(width: 8),
            Container(
              width: 120,
              height: 24,
              decoration: BoxDecoration(
                color: isMe
                    ? theme.colorScheme.onPrimary.withOpacity(0.3)
                    : theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(message.duration ?? 0),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isMe ? theme.colorScheme.onPrimary : null,
              ),
            ),
          ],
        );
      case 'file':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? 'Файл',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isMe ? theme.colorScheme.onPrimary : null,
                    ),
                  ),
                  if (message.fileSize != null)
                    Text(
                      _formatFileSize(message.fileSize!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isMe
                            ? theme.colorScheme.onPrimary.withOpacity(0.7)
                            : theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      default:
        return Text(
          message.content ?? '',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isMe ? theme.colorScheme.onPrimary : null,
          ),
        );
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
