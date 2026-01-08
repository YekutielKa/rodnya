import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/chat_bloc.dart';
import '../../data/models/chat_model.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../calls/call_manager.dart';

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
      context.read<ChatBloc>().add(const LoadMoreMessages());
    }
  }

  String _getCurrentUserId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.id;
    }
    return '';
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    context.read<ChatBloc>().add(SendTextMessage(content));
    _messageController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _getCurrentUserId();
    
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        // Build AppBar
        String title = 'Чат';
        String? subtitle;
        bool isOnline = false;

        if (state is ChatLoaded) {
          title = state.chat.getDisplayName(currentUserId);
          if (state.chat.type == ChatType.direct) {
            isOnline = state.chat.isOtherOnline(currentUserId);
            if (state.typingUsers.isNotEmpty) {
              subtitle = 'печатает...';
            } else if (isOnline) {
              subtitle = 'в сети';
            }
          } else {
            if (state.typingUsers.isNotEmpty) {
              final names = state.typingUsers.values.join(', ');
              subtitle = '$names печатает...';
            } else {
              subtitle = '${state.chat.participants.length} участников';
            }
          }
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                _buildAvatar(state, currentUserId, isOnline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: isOnline || (state is ChatLoaded && state.typingUsers.isNotEmpty)
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                onPressed: state is ChatLoaded && state.chat.type == ChatType.direct
                    ? () {
                        final other = state.chat.getOtherParticipant(currentUserId);
                        if (other != null) {
                          CallManager.instance.initiateCall(
                            recipientId: other.userId,
                            recipientName: other.name ?? 'Неизвестный',
                            recipientAvatar: other.avatarUrl,
                            isVideo: true,
                          );
                        }
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.call_outlined),
                onPressed: state is ChatLoaded && state.chat.type == ChatType.direct
                    ? () {
                        final other = state.chat.getOtherParticipant(currentUserId);
                        if (other != null) {
                          CallManager.instance.initiateCall(
                            recipientId: other.userId,
                            recipientName: other.name ?? 'Неизвестный',
                            recipientAvatar: other.avatarUrl,
                            isVideo: false,
                          );
                        }
                      }
                    : null,
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  // TODO: Handle menu actions
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'search', child: Text('Поиск')),
                  const PopupMenuItem(value: 'mute', child: Text('Без звука')),
                  const PopupMenuItem(value: 'clear', child: Text('Очистить чат')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Messages list
              Expanded(
                child: _buildMessagesList(state, currentUserId),
              ),
              
              // Reply indicator
              if (state is ChatLoaded && state.replyTo != null)
                _buildReplyIndicator(state.replyTo!),
              
              // Input field
              _buildInputField(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(ChatState state, String currentUserId, bool isOnline) {
    String? avatarUrl;
    if (state is ChatLoaded) {
      avatarUrl = state.chat.getDisplayAvatar(currentUserId);
    }

    return Stack(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.indigo.shade100,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? const Icon(Icons.person, color: Colors.indigo)
              : null,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessagesList(ChatState state, String currentUserId) {
    if (state is ChatLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ChatError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message, textAlign: TextAlign.center),
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

    if (state is! ChatLoaded) {
      return const SizedBox.shrink();
    }

    if (state.messages.isEmpty) {
      return const Center(
        child: Text(
          'Нет сообщений\nНапишите первое сообщение!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      itemCount: state.messages.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.isLoadingMore && index == state.messages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final message = state.messages[index];
        final isMe = message.senderId == currentUserId;
        
        // Check if we need date separator
        final showDateSeparator = _shouldShowDateSeparator(
          state.messages, index,
        );

        return Column(
          children: [
            if (showDateSeparator)
              _buildDateSeparator(message.createdAt),
            _MessageBubble(
              message: message,
              isMe: isMe,
              onReply: () {
                context.read<ChatBloc>().add(SetReplyTo(message));
                _focusNode.requestFocus();
              },
              onDelete: isMe ? () {
                context.read<ChatBloc>().add(DeleteMessage(message.id));
              } : null,
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowDateSeparator(List<MessageModel> messages, int index) {
    if (index == messages.length - 1) return true;
    
    final currentDate = messages[index].createdAt;
    final previousDate = messages[index + 1].createdAt;
    
    return currentDate.day != previousDate.day ||
           currentDate.month != previousDate.month ||
           currentDate.year != previousDate.year;
  }

  Widget _buildDateSeparator(DateTime date) {
    String text;
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    
    if (date.year == now.year && 
        date.month == now.month && 
        date.day == now.day) {
      text = 'Сегодня';
    } else if (date.year == yesterday.year && 
               date.month == yesterday.month && 
               date.day == yesterday.day) {
      text = 'Вчера';
    } else {
      text = DateFormat('d MMMM yyyy', 'ru').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyIndicator(MessageModel replyTo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  replyTo.senderName ?? 'Неизвестный',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                    fontSize: 13,
                  ),
                ),
                Text(
                  replyTo.content ?? _getMediaTypeText(replyTo.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              context.read<ChatBloc>().add(const ClearReplyTo());
            },
          ),
        ],
      ),
    );
  }

  String _getMediaTypeText(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '🖼 Фото';
      case MessageType.video:
        return '🎬 Видео';
      case MessageType.audio:
        return '🎵 Аудио';
      case MessageType.voice:
        return '🎤 Голосовое сообщение';
      case MessageType.file:
        return '📎 Файл';
      default:
        return '';
    }
  }

  Widget _buildInputField(ChatState state) {
    final isSending = state is ChatLoaded && state.isSending;
    
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            icon: const Icon(Icons.attach_file),
            color: Colors.grey.shade600,
            onPressed: () {
              _showAttachmentOptions();
            },
          ),
          
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Сообщение...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  // Emoji button
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    color: Colors.grey.shade600,
                    onPressed: () {
                      // TODO: Show emoji picker
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 4),
          
          // Send button
          Container(
            decoration: const BoxDecoration(
              color: Colors.indigo,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send),
              color: Colors.white,
              onPressed: isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purple.shade100,
                child: const Icon(Icons.image, color: Colors.purple),
              ),
              title: const Text('Фото'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Pick image
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.videocam, color: Colors.blue),
              ),
              title: const Text('Видео'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Pick video
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: const Icon(Icons.insert_drive_file, color: Colors.orange),
              ),
              title: const Text('Файл'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Pick file
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: const Icon(Icons.camera_alt, color: Colors.green),
              ),
              title: const Text('Камера'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Open camera
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MESSAGE BUBBLE WIDGET
// ============================================================================

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback onReply;
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.onReply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedMessage(context);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: isMe ? 48 : 0,
            right: isMe ? 0 : 48,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe ? Colors.indigo : Colors.grey.shade200,
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
              // Reply preview
              if (message.replyTo != null)
                _buildReplyPreview(context),
              
              // Sender name (for groups, not me)
              if (!isMe && message.senderName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.senderName!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isMe ? Colors.white70 : Colors.indigo,
                    ),
                  ),
                ),
              
              // Message content based on type
              _buildContent(context),
              
              // Time and status
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white60 : Colors.grey,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeletedMessage(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              'Сообщение удалено',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final reply = message.replyTo!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white60 : Colors.indigo,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderName ?? 'Неизвестный',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: isMe ? Colors.white70 : Colors.indigo,
            ),
          ),
          Text(
            reply.content ?? _getMediaTypeText(reply.type),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content ?? '',
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        );
      
      case MessageType.image:
        return _buildImageContent(context);
      
      case MessageType.video:
        return _buildVideoContent(context);
      
      case MessageType.voice:
      case MessageType.audio:
        return _buildAudioContent(context);
      
      case MessageType.file:
        return _buildFileContent(context);
    }
  }

  Widget _buildImageContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: message.mediaUrl != null
              ? Image.network(
                  message.mediaUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 200,
                      height: 150,
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) {
                    return Container(
                      width: 200,
                      height: 150,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image),
                    );
                  },
                )
              : Container(
                  width: 200,
                  height: 150,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.image),
                ),
        ),
        if (message.content != null && message.content!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message.content!,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: message.thumbnailUrl != null
                  ? Image.network(
                      message.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: 200,
                      height: 150,
                    )
                  : Container(
                      width: 200,
                      height: 150,
                      color: Colors.grey.shade800,
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
            if (message.duration != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(message.duration!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (message.content != null && message.content!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message.content!,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAudioContent(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? Colors.white24 : Colors.indigo.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            message.type == MessageType.voice ? Icons.mic : Icons.audiotrack,
            color: isMe ? Colors.white : Colors.indigo,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        // Waveform placeholder
        Expanded(
          child: Container(
            height: 30,
            decoration: BoxDecoration(
              color: isMe ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          message.duration != null ? _formatDuration(message.duration!) : '--:--',
          style: TextStyle(
            color: isMe ? Colors.white70 : Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFileContent(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe ? Colors.white24 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.insert_drive_file,
            color: isMe ? Colors.white : Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.fileName ?? 'Файл',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
              if (message.fileSize != null)
                Text(
                  _formatFileSize(message.fileSize!),
                  style: TextStyle(
                    fontSize: 12,
                    color: isMe ? Colors.white60 : Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color = Colors.white60;

    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.lightBlueAccent;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = Colors.redAccent;
        break;
    }

    return Icon(icon, size: 14, color: color);
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Ответить'),
              onTap: () {
                Navigator.pop(ctx);
                onReply();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Копировать'),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: Copy to clipboard
              },
            ),
            if (isMe && message.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Редактировать'),
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Edit message
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _getMediaTypeText(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '🖼 Фото';
      case MessageType.video:
        return '🎬 Видео';
      case MessageType.audio:
        return '🎵 Аудио';
      case MessageType.voice:
        return '🎤 Голосовое';
      case MessageType.file:
        return '📎 Файл';
      default:
        return '';
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
