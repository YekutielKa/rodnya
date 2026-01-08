import 'package:equatable/equatable.dart';

enum ChatType { direct, group }
enum MessageType { text, image, video, voice, audio, file }
enum MessageStatus { sending, sent, delivered, read, failed }

class ChatModel extends Equatable {
  final String id;
  final ChatType type;
  final String? name;
  final String? description;
  final String? avatarUrl;
  final List<ChatMember> participants;
  final MessageModel? lastMessage;
  final int unreadCount;
  final bool isMuted;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ChatModel({
    required this.id, required this.type, this.name, this.description, this.avatarUrl,
    required this.participants, this.lastMessage, this.unreadCount = 0,
    this.isMuted = false, this.isPinned = false, required this.createdAt, this.updatedAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      type: json['type'] == 'group' ? ChatType.group : ChatType.direct,
      name: json['name'] as String?,
      description: json['description'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      participants: (json['participants'] as List<dynamic>?)?.map((e) => ChatMember.fromJson(e)).toList() ?? [],
      lastMessage: json['last_message'] != null ? MessageModel.fromJson(json['last_message']) : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      isMuted: json['is_muted'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type == ChatType.group ? 'group' : 'direct', 'name': name,
    'description': description, 'avatar_url': avatarUrl,
    'participants': participants.map((e) => e.toJson()).toList(),
    'last_message': lastMessage?.toJson(), 'unread_count': unreadCount,
    'is_muted': isMuted, 'is_pinned': isPinned, 'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  ChatModel copyWith({String? name, String? description, String? avatarUrl, List<ChatMember>? participants,
    MessageModel? lastMessage, int? unreadCount, bool? isMuted, bool? isPinned}) {
    return ChatModel(id: id, type: type, name: name ?? this.name, description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl, participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage, unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted, isPinned: isPinned ?? this.isPinned, createdAt: createdAt, updatedAt: updatedAt);
  }

  String getDisplayName(String currentUserId) {
    if (type == ChatType.group) return name ?? 'Группа';
    final other = getOtherParticipant(currentUserId);
    return other?.name ?? 'Чат';
  }

  String? getDisplayAvatar(String currentUserId) {
    if (type == ChatType.group) return avatarUrl;
    return getOtherParticipant(currentUserId)?.avatarUrl;
  }

  ChatMember? getOtherParticipant(String currentUserId) {
    if (type != ChatType.direct) return null;
    try { return participants.firstWhere((p) => p.userId != currentUserId); }
    catch (_) { return participants.isNotEmpty ? participants.first : null; }
  }

  bool isOtherOnline(String currentUserId) => getOtherParticipant(currentUserId)?.isOnline ?? false;

  @override
  List<Object?> get props => [id, type, name, avatarUrl, participants, lastMessage, unreadCount, isMuted, isPinned];
}

class ChatMember extends Equatable {
  final String id;
  final String chatId;
  final String userId;
  final String? name;
  final String? avatarUrl;
  final String role;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? joinedAt;

  const ChatMember({required this.id, required this.chatId, required this.userId, this.name, this.avatarUrl,
    this.role = 'member', this.isOnline = false, this.lastSeen, this.joinedAt});

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    return ChatMember(
      id: json['id'] as String? ?? '', chatId: json['chat_id'] as String? ?? '', userId: json['user_id'] as String,
      name: json['name'] as String?, avatarUrl: json['avatar_url'] as String?, role: json['role'] as String? ?? 'member',
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen'] as String) : null,
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'chat_id': chatId, 'user_id': userId, 'name': name, 'avatar_url': avatarUrl,
    'role': role, 'is_online': isOnline, 'last_seen': lastSeen?.toIso8601String(), 'joined_at': joinedAt?.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, userId, name, isOnline];
}

class MessageModel extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final MessageType type;
  final String? content;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final int? duration;
  final MessageModel? replyTo;
  final List<String> readBy;
  final MessageStatus status;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isEdited;
  final bool isDeleted;

  const MessageModel({required this.id, required this.chatId, required this.senderId, this.senderName, this.senderAvatar,
    required this.type, this.content, this.mediaUrl, this.thumbnailUrl, this.fileName, this.fileSize, this.duration,
    this.replyTo, this.readBy = const [], this.status = MessageStatus.sent, required this.createdAt,
    this.editedAt, this.isEdited = false, this.isDeleted = false});

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String, chatId: json['chat_id'] as String, senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String?, senderAvatar: json['sender_avatar'] as String?,
      type: _parseMessageType(json['type'] as String? ?? 'text'), content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?, thumbnailUrl: json['thumbnail_url'] as String?,
      fileName: json['file_name'] as String?, fileSize: json['file_size'] as int?, duration: json['duration'] as int?,
      replyTo: json['reply_to'] != null ? MessageModel.fromJson(json['reply_to']) : null,
      readBy: (json['read_by'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      status: _parseMessageStatus(json['status'] as String? ?? 'sent'),
      createdAt: DateTime.parse(json['created_at'] as String),
      editedAt: json['edited_at'] != null ? DateTime.parse(json['edited_at'] as String) : null,
      isEdited: json['is_edited'] as bool? ?? false, isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'chat_id': chatId, 'sender_id': senderId, 'sender_name': senderName, 'sender_avatar': senderAvatar,
    'type': type.name, 'content': content, 'media_url': mediaUrl, 'thumbnail_url': thumbnailUrl,
    'file_name': fileName, 'file_size': fileSize, 'duration': duration, 'reply_to': replyTo?.toJson(),
    'read_by': readBy, 'status': status.name, 'created_at': createdAt.toIso8601String(),
    'edited_at': editedAt?.toIso8601String(), 'is_edited': isEdited, 'is_deleted': isDeleted,
  };

  factory MessageModel.optimistic({required String id, required String chatId, required String senderId,
    required MessageType type, String? content, String? mediaUrl, String? thumbnailUrl, String? fileName,
    int? fileSize, int? duration, MessageModel? replyTo}) {
    return MessageModel(id: id, chatId: chatId, senderId: senderId, type: type, content: content,
      mediaUrl: mediaUrl, thumbnailUrl: thumbnailUrl, fileName: fileName, fileSize: fileSize, duration: duration,
      replyTo: replyTo, status: MessageStatus.sending, createdAt: DateTime.now());
  }

  MessageModel copyWith({String? content, String? mediaUrl, String? thumbnailUrl, MessageStatus? status,
    List<String>? readBy, bool? isEdited, bool? isDeleted, DateTime? editedAt}) {
    return MessageModel(id: id, chatId: chatId, senderId: senderId, senderName: senderName, senderAvatar: senderAvatar,
      type: type, content: content ?? this.content, mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl, fileName: fileName, fileSize: fileSize, duration: duration,
      replyTo: replyTo, readBy: readBy ?? this.readBy, status: status ?? this.status, createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt, isEdited: isEdited ?? this.isEdited, isDeleted: isDeleted ?? this.isDeleted);
  }

  String getPreviewText() {
    if (isDeleted) return 'Сообщение удалено';
    switch (type) {
      case MessageType.text: return content ?? '';
      case MessageType.image: return '📷 Фото';
      case MessageType.video: return '🎬 Видео';
      case MessageType.voice: return '🎤 Голосовое сообщение';
      case MessageType.audio: return '🎵 Аудио';
      case MessageType.file: return '📎 ${fileName ?? "Файл"}';
    }
  }

  static MessageType _parseMessageType(String type) {
    switch (type.toLowerCase()) {
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'voice': return MessageType.voice;
      case 'audio': return MessageType.audio;
      case 'file': return MessageType.file;
      default: return MessageType.text;
    }
  }

  static MessageStatus _parseMessageStatus(String status) {
    switch (status.toLowerCase()) {
      case 'sending': return MessageStatus.sending;
      case 'sent': return MessageStatus.sent;
      case 'delivered': return MessageStatus.delivered;
      case 'read': return MessageStatus.read;
      case 'failed': return MessageStatus.failed;
      default: return MessageStatus.sent;
    }
  }

  @override
  List<Object?> get props => [id, status, isDeleted, readBy, isEdited];
}
